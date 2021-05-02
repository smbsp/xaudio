//SPDX-License-Identifier: Unlicense
pragma solidity 0.6.2;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/Pausable.sol";

import "./interface/IDelegateManager.sol";

contract xAUDIO is
    Initializable,
    ERC20UpgradeSafe,
    OwnableUpgradeSafe,
    PausableUpgradeSafe
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 private constant INITIAL_SUPPLY_MULTIPLIER = 10;
    uint256 private constant LIQUIDATION_TIME_PERIOD = 7 days;
    uint256 private constant BUFFER_TARGET = 20; // 5% target
    uint256 private constant MAX_UINT = 2**256 - 1;
    address public constant serviceProvider =
        0xc1f351FE81dFAcB3541e59177AC71Ed237BD15D0;

    uint256 public adminActiveTimestamp;
    uint256 public withdrawableAudioFees;

    IERC20 private audio;

    IDelegateManager private delegateManager;

    address private manager;
    address private manager2;

    struct FeeDivisors {
        uint256 mintFee;
        uint256 burnFee;
        uint256 claimFee;
    }

    FeeDivisors public feeDivisors;

    string public mandate;

    event FeeDivisorsSet(uint256 mintFee, uint256 burnFee, uint256 claimFee);
    event FeeWithdraw(uint256 ethFee, uint256 audioFee);

    function initialize(
        string calldata _symbol,
        IERC20 _audio,
        IDelegateManager _delegateManager,
        uint256 _mintFeeDivisor,
        uint256 _burnFeeDivisor,
        uint256 _claimFeeDivisor
    ) external initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __ERC20_init_unchained("xAUDIO", _symbol);

        audio = _audio;
        delegateManager = _delegateManager;
        _setFeeDivisors(_mintFeeDivisor, _burnFeeDivisor, _claimFeeDivisor);
    }

    /*
     * @dev Mint xAUDIO using AUDIO
     * @param audioAmount: AUDIO tokens to contribute
     */
    function mintWithToken(uint256 audioAmount) external whenNotPaused {
        require(audioAmount > 0, "Must send token");
        audio.safeTransferFrom(msg.sender, address(this), audioAmount);

        uint256 fee = _calculateFee(audioAmount, feeDivisors.mintFee);
        _incrementWithdrawableAudioFees(fee);

        return _mintInternal(audioAmount.sub(fee));
    }

    function _mintInternal(uint256 _incrementalAudio) private {
        uint256 mintAmount =
            calculateMintAmount(_incrementalAudio, totalSupply());

        return super._mint(msg.sender, mintAmount);
    }

    function calculateMintAmount(uint256 incrementalAudio, uint256 totalSupply)
        public
        view
        returns (uint256 mintAmount)
    {
        if (totalSupply == 0)
            return incrementalAudio.mul(INITIAL_SUPPLY_MULTIPLIER);
        uint256 previousNav = getNav().sub(incrementalAudio);
        mintAmount = (incrementalAudio).mul(totalSupply).div(previousNav);
    }

    /*
     * @dev Burn xAUDIO tokens
     * @notice Will fail if pro rata balance exceeds available liquidity
     * @param tokenAmount: xAUDIO tokens to burn
     */
    function burn(uint256 tokenAmount) external {
        require(tokenAmount > 0, "Must send xAUDIO");

        uint256 stakedBalance = getStakedBalance();
        uint256 bufferBalance = getBufferBalance();
        uint256 audioHoldings = stakedBalance.add(bufferBalance);
        uint256 proRataAudio =
            audioHoldings.mul(tokenAmount).div(totalSupply());

        require(proRataAudio <= bufferBalance, "Insufficient exit liquidity");
        super._burn(msg.sender, tokenAmount);

        uint256 fee = _calculateFee(proRataAudio, feeDivisors.burnFee);
        _incrementWithdrawableAudioFees(fee);
        audio.safeTransfer(msg.sender, proRataAudio.sub(fee));
    }

    /* ========================================================================================= */
    /*                                            Management                                     */
    /* ========================================================================================= */

    function getNav() public view returns (uint256) {
        return getStakedBalance().add(getBufferBalance());
    }

    function getStakedBalance() public view returns (uint256) {
        return delegateManager.getTotalDelegatorStake(address(this));
    }

    function getBufferBalance() public view returns (uint256) {
        return audio.balanceOf(address(this)).sub(withdrawableAudioFees);
    }

    function stake() external onlyOwnerOrManager {
        _certifyAdmin();
        uint256 stakedBalance = getStakedBalance();
        uint256 bufferBalance = getBufferBalance();
        uint256 targetBuffer =
            (stakedBalance.add(bufferBalance)).div(BUFFER_TARGET);
        if (bufferBalance > targetBuffer) {
            delegateManager.delegateStake(
                serviceProvider,
                bufferBalance.sub(targetBuffer)
            );
        }
    }

    function unstake(uint256 _amount) external onlyOwnerOrManager {
        require(
            adminActiveTimestamp.add(LIQUIDATION_TIME_PERIOD) < block.timestamp,
            "Liquidation time not elapsed"
        );
        delegateManager.requestUndelegateStake(address(this), _amount);
        delegateManager.undelegateStake();
    }

    function _calculateFee(uint256 _value, uint256 _feeDivisor)
        internal
        pure
        returns (uint256 fee)
    {
        if (_feeDivisor > 0) {
            fee = _value.div(_feeDivisor);
        }
    }

    function _incrementWithdrawableAudioFees(uint256 _feeAmount) private {
        withdrawableAudioFees = withdrawableAudioFees.add(_feeAmount);
    }

    /* ========================================================================================= */
    /*                                              Utils                                        */
    /* ========================================================================================= */

    /*
     * @notice Inverse of fee i.e., a fee divisor of 100 == 1%
     * @notice Three fee types
     * @dev Mint fee 0 or <= 2%
     * @dev Burn fee 0 or <= 1%
     * @dev Claim fee 0 <= 4%
     */
    function setFeeDivisors(
        uint256 mintFeeDivisor,
        uint256 burnFeeDivisor,
        uint256 claimFeeDivisor
    ) public onlyOwner {
        _setFeeDivisors(mintFeeDivisor, burnFeeDivisor, claimFeeDivisor);
    }

    function _setFeeDivisors(
        uint256 _mintFeeDivisor,
        uint256 _burnFeeDivisor,
        uint256 _claimFeeDivisor
    ) private {
        require(_mintFeeDivisor == 0 || _mintFeeDivisor >= 50, "Invalid fee");
        require(_burnFeeDivisor == 0 || _burnFeeDivisor >= 100, "Invalid fee");
        require(_claimFeeDivisor >= 25, "Invalid fee");
        feeDivisors.mintFee = _mintFeeDivisor;
        feeDivisors.burnFee = _burnFeeDivisor;
        feeDivisors.claimFee = _claimFeeDivisor;

        emit FeeDivisorsSet(_mintFeeDivisor, _burnFeeDivisor, _claimFeeDivisor);
    }

    function pauseContract() public onlyOwnerOrManager returns (bool) {
        _pause();
        return true;
    }

    function unpauseContract() public onlyOwnerOrManager returns (bool) {
        _unpause();
        return true;
    }

    /*
     * @notice Registers that admin is present and active
     * @notice If admin isn't certified within liquidation time period,
     * emergencyUnstake function becomes callable
     */
    function _certifyAdmin() private {
        adminActiveTimestamp = block.timestamp;
    }

    function setManager(address _manager) external onlyOwner {
        manager = _manager;
    }

    function setManager2(address _manager2) external onlyOwner {
        manager2 = _manager2;
    }

    function approveAudio(address _toApprove) external onlyOwnerOrManager {
        audio.safeApprove(_toApprove, MAX_UINT);
    }

    /*
     * @notice Emergency function in case of errant transfer of
     * xAUDIO token directly to contract
     */
    function withdrawNativeToken() public onlyOwnerOrManager {
        uint256 tokenBal = balanceOf(address(this));
        if (tokenBal > 0) {
            IERC20(address(this)).safeTransfer(msg.sender, tokenBal);
        }
    }

    /*
     * @notice Withdraw function for ETH and AUDIO fees
     */
    function withdrawFees() public onlyOwner {
        uint256 ethBal = address(this).balance;
        (bool success, ) = msg.sender.call.value(ethBal)("");
        require(success, "Transfer failed");

        uint256 audioFees = withdrawableAudioFees;
        withdrawableAudioFees = 0;
        audio.safeTransfer(msg.sender, audioFees);

        emit FeeWithdraw(ethBal, audioFees);
    }

    modifier onlyOwnerOrManager {
        require(
            msg.sender == owner() ||
                msg.sender == manager ||
                msg.sender == manager2,
            "Non-admin caller"
        );
        _;
    }

    receive() external payable {
        require(msg.sender != tx.origin, "Errant ETH deposit");
    }
}
