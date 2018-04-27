pragma solidity ^0.4.0;

//INPUT PARAMETERS: 6000, 1533686400, 1500000000000000000
//ROPSTEN TEST:

//Branch Marko

import "http://github.com/oraclize/ethereum-api/oraclizeAPI_0.5.sol";
import "./libs/SafeMath.sol";

contract FuturesContract is usingOraclize {

    using SafeMath for uint256;

    uint public neutralExRate;
    uint public matirityTime;
    uint public collateral;
    uint public collateralOfOwner;
    uint public collateralOfTaker;
    bool ownerIsLong;
    address owner;
    address taker;

    string public BTCpriceEUR;

    event newOraclizeQuery(string description);
    event newKrakenPriceTicker(string price);

    mapping(address => uint) collaterals;

    function FuturesContract(uint _neutralExRate, uint _matirityTime, uint _collateral){
        owner = msg.sender;
        neutralExRate = _neutralExRate;
        matirityTime = _matirityTime;
        collateral = _collateral;
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
        checkPrice();
    }

    enum Phase {
    Created,
    Waiting,
    Live
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
            collaterals[_funder] += msg.value;
            //collateralOfOwner += msg.value;
            setSalePhase(Phase.Waiting);
        } else {
            require(msg.value >= collateral);
            taker = _funder;
            //collateralOfTaker += msg.value;
            collaterals[taker] += msg.value;
            setSalePhase(Phase.Live);
        }
    }

    function __callback(bytes32 myid, string result, bytes proof) {
        if (msg.sender != oraclize_cbAddress()) throw;
        BTCpriceEUR = result;
        newKrakenPriceTicker(BTCpriceEUR);
        if (matirityTime >= now) {
            uint actualPrice = stringToUint(BTCpriceEUR);
            liquidateByMe(actualPrice);
        } else {
            checkPrice();
        }
    }

    function checkPrice() payable {
        if (oraclize_getPrice("URL") > this.balance) {
            newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
            oraclize_query(60, "URL", "json(https://api.kraken.com/0/public/Ticker?pair=XXBTZEUR).result.XXBTZEUR.c.0");
        }
    }

    function liquidateByMe(uint liquidationExRate) internal returns (bool) {       // liquidationPrice can be set internaly by getPrice function if conditions are met
        uint256 profit = (liquidationExRate - neutralExRate);

        if ((profit >= 0 && ownerIsLong == true) || (profit < 0 && ownerIsLong == false)) {

            if(profit < 0) {
                profit =-1 * profit;
            }

            //owner.transfer(collateralOfOwner + profit);
            //taker.transfer(collateralOfTaker - profit);

            owner.transfer(collaterals[owner] + profit);
            taker.transfer(collaterals[taker] - profit);
        }

        if(profit < 0) {
            profit = -1 * profit;
        }

        //owner.transfer(collateralOfOwner - profit);
        //taker.transfer(collateralOfTaker + profit);

        owner.transfer(collaterals[owner] -= profit);
        taker.transfer(collaterals[taker] + profit);
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

    function validFunding() internal constant returns (bool) {
        bool withinPeriod = now <= matirityTime;
        bool nonZeroPurchase = msg.value != 0;
        bool aboveLimit = msg.value >= collateral;

        return withinPeriod && nonZeroPurchase && aboveLimit;
    }

    function setSalePhase(Phase _nextPhase) internal {
        bool canSwitchPhase
        =  (currentPhase == Phase.Created && _nextPhase == Phase.Waiting)
        || (currentPhase == Phase.Waiting && _nextPhase == Phase.Live);

        require(canSwitchPhase);
        currentPhase = _nextPhase;
        LogPhaseSwitch(_nextPhase);
    }

    // Constant functions
    function getCurrentPhase() public constant returns (string CurrentPhase) {
        if (currentPhase == Phase.Created) {
            return "Created";
        } else if (currentPhase == Phase.Waiting) {
            return "Waiting";
        } else if (currentPhase == Phase.Live) { // absdfdfdf
            return "Live";
        }
    }

    function stringToUint(string s) constant returns (uint) {
        bytes memory b = bytes(s);
        uint result = 0;
        for (uint i = 0; i < b.length; i++) { // c = b[i] was not needed
            if (b[i] >= 48 && b[i] <= 57) {
                result = result * 10 + (uint(b[i]) - 48); // bytes and int are not compatible with the operator -.
            }
        }
        return result; // this was missing
    }

    function uintToString(uint v) constant returns (string) {
        uint maxlength = 100;
        bytes memory reversed = new bytes(maxlength);
        uint i = 0;
        while (v != 0) {
            uint remainder = v % 10;
            v = v / 10;
            reversed[i++] = byte(48 + remainder);
        }
        bytes memory s = new bytes(i); // i + 1 is inefficient
        for (uint j = 0; j < i; j++) {
            s[j] = reversed[i - j - 1]; // to avoid the off-by-one error
        }
        string memory str = string(s);  // memory isn't implicitly convertible to storage
        return str; // this was missing
    }
}
