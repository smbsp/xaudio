pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// https://etherscan.io/address/0x612B4367a7Ae2cf346dC3759623a9c22102ff8d6
contract MockDelegateManager {
    uint256 amount;
    IERC20 audio;

    constructor(IERC20 _audio) public {
        audio = _audio;
    }

    function delegateStake(address _targetSP, uint256 _amount)
        external
        returns (uint256)
    {
        audio.transferFrom(msg.sender, address(this), _amount);
    }

    function getTotalDelegatorStake(address _delegator)
        external
        view
        returns (uint256)
    {
        return audio.balanceOf(address(this));
    }

    function requestUndelegateStake(address _target, uint256 _amount)
        external
        returns (uint256)
    {
        amount = _amount;
    }

    function undelegateStake() external returns (uint256) {
        audio.transfer(msg.sender, amount);
    }
}
