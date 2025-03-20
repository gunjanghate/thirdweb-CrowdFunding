//SPDX-License-Identifier:MIT

pragma solidity ^0.8.28;

contract CrowdFunding {
    // mapping(address => uint256) public contributers;
    // address public manager;
    // uint256 public minContri;
    // uint256 public deadline;
    // uint256 public target;
    // uint256 public raisedAmt;
    // uint256 public noOfContri;

    // constructor(uint256 _target, uint256 _deadline) {
    //     target = _target;
    //     deadline = block.timestamp + _deadline;
    //     minContri = 100 wei;
    //     manager = msg.sender;
    // }

    // struct Req{
    //     string desc;
    //     address payable recipient;
    //     uint value;
    //     bool completed;
    //     uint noOfVoters;
    //     mapping(address=>bool) voters;
    // }

    // mapping(uint=>Req) public requests;
    // uint public numReq;

    // function sendETH() public payable {
    //     require(block.timestamp <= deadline, "Ether cant be sent as its end");
    //     require(msg.value >= minContri, "Ether cant be sent as its not enough");
    //     if (contributers[msg.sender] == 0) {
    //         noOfContri++;
    //     }
    //     if (msg.value >= minContri) {
    //         contributers[msg.sender] += msg.value;
    //         raisedAmt += msg.value;
    //     }
    // }

    // function getBalance() public view returns(uint){
    //     return address(this).balance;
    // }

    // function refund() public{
    //     require(block.timestamp>deadline && raisedAmt<target, "No Ether Refunded");
    //     require(contributers[msg.sender]>0);
    //     address payable user = payable(msg.sender);
    //     user.transfer(contributers[msg.sender]);
    //     contributers[msg.sender] = 0;
    // }
    // modifier onlyManager{
    //     require(msg.sender==manager, "Unauthorized");
    //     _;
    // }

    // function CreateReq(string memory _desc, address payable _recipient, uint _value) public onlyManager {
    //     Req storage newReq = requests[numReq];
    //     numReq++;
    //     newReq.desc=_desc;
    //     newReq.recipient=_recipient;
    //     newReq.value=_value;
    //     newReq.completed=false;
    //     newReq.noOfVoters=0;
    // }

    // function VoteReq(uint _reqNum) public{
    //     require(contributers[msg.sender]>0,"You must be contributer");
    //     Req storage thisReq =requests[_reqNum];
    //     require(thisReq.voters[msg.sender]==false, "You have already voted");
    //     thisReq.voters[msg.sender]=true;
    //     thisReq.noOfVoters++;
    // }

    // function makePayment(uint _reqNo) public onlyManager{
    //     require(raisedAmt>=target);
    //     Req storage thisReq = requests[_reqNo];
    //     require(thisReq.completed==false, "The request has been completed");
    //     require(thisReq.noOfVoters > noOfContri/2,"Majority don't support");
    //     thisReq.recipient.transfer(thisReq.value);
    //     thisReq.completed=true;
    // }

    string public name;
    string public desc;
    uint256 public deadline;
    uint256 public target;
    address public owner;
    bool public paused;

    enum CampaignState {
        Active,
        Successful,
        Failed
    }
    CampaignState public state;

    struct Tier {
        string name;
        uint256 amt;
        uint256 backers;
    }

    struct Backer{
        uint256 totalContri;
        mapping(uint256 => bool) funded;

    }

    Tier[] public tiers;
    mapping(address=>Backer) public backers;
    modifier OnlyOwner() {
        require(msg.sender == owner, "Only Owner can do this");
        _;
    }
    modifier CampaignOpened() {
        require(state == CampaignState.Active, "Campaign is not Active!");
        _;
    }
    modifier NotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor(
        address _owner,
        string memory _name,
        string memory _desc,
        uint256 _target,
        uint256 _duration
    ) {
        name = _name;
        desc = _desc;
        target = _target;
        deadline = block.timestamp + (_duration * 1 days);
        owner = _owner;
        state = CampaignState.Active;
    }

    function checkAndUpdateCampaignState() internal {
        if (state == CampaignState.Active) {
            if (block.timestamp >= deadline) {
                state = address(this).balance >= target
                    ? CampaignState.Successful
                    : CampaignState.Failed;
            } else {
                state = address(this).balance >= target
                    ? CampaignState.Successful
                    : CampaignState.Active;
            }
        }
    }

    function fund(uint256 _tierIndex) public payable CampaignOpened NotPaused {
        require(_tierIndex < tiers.length, "Invalid Tier");
        require(msg.value == tiers[_tierIndex].amt, "Incorrect Amt");
        require(msg.value > 0, "Must Fund Amt greater than 0");

        tiers[_tierIndex].backers++;
        backers[msg.sender].totalContri +=msg.value;
        backers[msg.sender].funded[_tierIndex] = true;
        checkAndUpdateCampaignState();
    }

    function withdraw() public OnlyOwner {
        checkAndUpdateCampaignState();
        require(state == CampaignState.Successful, "Campaign is not Successful");
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdarw");

        payable(owner).transfer(balance);
    }

    function getContractBalance() public view OnlyOwner returns (uint256) {
        return address(this).balance;
    }

    function addTier(string memory _name, uint256 _amt) public OnlyOwner {
        require(_amt > 0, "Amt Must be greater than 0");
        tiers.push(Tier(_name, _amt, 0));
    }

    function removeTier(uint256 _index) public {
        require(_index < tiers.length, "Tiers doesn't exists");
        tiers[_index] = tiers[tiers.length - 1];
        tiers.pop();
    }

    function refund() public{
        checkAndUpdateCampaignState();
        // require(state == CampaignState.Failed, "Refunds Not needed");
        uint256 amt = backers[msg.sender].totalContri;
        require(amt>0,"Nothing to refund");
        backers[msg.sender].totalContri = 0;
        payable(msg.sender).transfer(amt);
    }

    function hasFundedTier(address _backer, uint256 _tierIndex) public view returns(bool){
        return backers[_backer].funded[_tierIndex];
    }

    function getTiers() public view returns(Tier[] memory){
        return tiers;
    }

    function togglePaused() public OnlyOwner{
        paused=!paused;
    }

    function getCampaignStatus() public view returns (CampaignState){
        if(state == CampaignState.Active && block.timestamp>deadline ){
           return address(this).balance >= target ? CampaignState.Successful : CampaignState.Failed; 
        }
        return state;
    }
    function extendDeadLine(uint256 _daysToAdd) public OnlyOwner CampaignOpened{
        deadline+= _daysToAdd*1 days;
    }
}
