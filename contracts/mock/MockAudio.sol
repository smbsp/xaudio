pragma solidity 0.6.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockAudio is ERC20 {
    constructor() public ERC20("Audius", "AUDIO") {
        _mint(msg.sender, 1000e18);
    }
}
