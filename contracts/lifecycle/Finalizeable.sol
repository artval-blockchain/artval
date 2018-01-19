pragma solidity ^0.4.18;

import '../ownership/Ownable.sol';

contract Finalizable is Ownable {

    bool public isFinalized = false;

    event Finalized();
    /**
     * @dev modifier to allow actions only when the contract IS finalized
     */
    modifier whenFinalized() {
        require(isFinalized);
        _;
    }

    /**
     * @dev modifier to allow actions only when the contract IS NOT finalized
     */
    modifier whenNotFinalized() {
        require(!isFinalized);
        _;
    }

    /**
     * @dev 
     */
    function finalize() onlyOwner whenNotFinalized external {
        // move to operational
        isFinalized = true;

        Finalized();
    }
}
