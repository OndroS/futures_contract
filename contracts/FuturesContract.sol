pragma solidity ^0.4.0;

//INPUT PARAMETERS: 6000, 1533686400, 1500000000000000000
//ROPSTEN TEST: 0x58a86ded501db24edacc280845e062431b7df79c

contract FuturesContract {

    uint public neutralPrice;
    uint public matirityTime;
    uint public collateral;
    uint public collateralOfOwner;
    uint public collateralOfTaker;
    address owner;
    address taker;

    function FuturesContract(uint _neutralPrice, uint _matirityTime, uint _collateral){
        owner = msg.sender;
        neutralPrice = _neutralPrice;
        matirityTime = _matirityTime;
        collateral = _collateral;
    }

    enum Phase {
        Created,
        Waiting,
        Confirmed
    }

    Phase public currentPhase = Phase.Created;
    event LogPhaseSwitch(Phase phase);

    //fallback function can be used to send collateral
    function () payable {
        fundingColateral(msg.sender);
    }

    function fundingColateral(address _funder) public payable {
        require(_funder != address(0));
        require(validFunding());
        if (_funder == owner) {
            require(currentPhase == Phase.Created);
            collateralOfOwner += msg.value;
            setSalePhase(Phase.Waiting);
        } else {
            require(msg.value >= collateral);
            taker = _funder;
            collateralOfTaker += msg.value;
            setSalePhase(Phase.Confirmed);
        }
    }

    function checkPrizes() public {
        //TODO: Oracles, logic and other shit
    }

    function getBalance() public constant returns(uint256) {
        return this.balance;
    }

    function getCreator() public constant returns(address) {
        return owner;
    }

    function getTaker() public constant returns(address) {
        return taker;
    }

    function validFunding() internal view returns (bool) {
        bool withinPeriod = now <= matirityTime;
        bool nonZeroPurchase = msg.value != 0;
        bool aboveLimit = msg.value >= collateral;

        return withinPeriod && nonZeroPurchase && aboveLimit;
    }

    function setSalePhase(Phase _nextPhase) internal {
        bool canSwitchPhase
        =  (currentPhase == Phase.Created && _nextPhase == Phase.Waiting)
        || (currentPhase == Phase.Waiting && _nextPhase == Phase.Confirmed);

        require(canSwitchPhase);
        currentPhase = _nextPhase;
        LogPhaseSwitch(_nextPhase);
    }

    // Constant functions
    function getCurrentPhase() public view returns (string CurrentPhase) {
        if (currentPhase == Phase.Created) {
            return "Created";
        } else if (currentPhase == Phase.Waiting) {
            return "Waiting";
        } else if (currentPhase == Phase.Confirmed) {
            return "Confirmed";
        }
    }
}
