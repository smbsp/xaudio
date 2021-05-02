pragma solidity 0.6.2;

interface IDelegateManager {
    function delegateStake(address _targetSP, uint256 _amount)
        external
        returns (uint256);

    function getTotalDelegatorStake(address _delegator)
        external
        view
        returns (uint256);

    function requestUndelegateStake(address _target, uint256 _amount)
        external
        returns (uint256);

    function undelegateStake() external returns (uint256);
}
