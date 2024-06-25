//SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

//Owner Specification
contract Ownable {
    address payable owner;

    modifier onlyOwner(){
        require(msg.sender == owner, "must be owner");
        _;
    }
    constructor(){
        owner = payable(msg.sender);
    }
}

//Commision Bank.
contract Commision is Ownable{

    //Total commision collected by the system(admin) until last withdrawl.
    function checkCommision()public view onlyOwner returns(uint256){
        return address(this).balance;
    }

    //Withdraw Commision by admin(owner).
    function withdrawCommision()external payable onlyOwner{
        owner.transfer(address(this).balance);
        require(true);
    }
    receive()external payable{}
    fallback() external payable{}
}

//Project Management.
contract ManageProject is Ownable{
    //tract total no. of projects.
    uint public totalnoOfProjects;

    //tract  all successfully funded projects
    uint  public totalSuccessfullyFundedProj;

    //keys to tract all projects
    uint[] keys;

    //the address that is used is the deployed "Commision" smart contract address
    address payable _commision;

    //Initializing the commisionContractAddresss.
    constructor(address _commisionContractAddress){
        _commision=payable(_commisionContractAddress);
        super;
    }

    //Number of Projects that are Created by a perticular user.
    mapping(address=>uint) public noOfProjAddWise;    

    //Project Structure
    struct Project{
        address creator;
        string name;
        string description;
        address highestFunder;
        uint highestFunding;
        uint fundingGoal;
        uint deadline;
        uint amountRaised;
        //this project is completely funded or not;
        bool funded;
    }

    //projectId=>project details keyvaluepair
    mapping(uint=>Project)public projects;

    ////projectId=>user=>contribution amount/funding amount
    mapping(uint=>mapping(address=>uint))public contributions;

    //projectId->wheather the id is used or not
    mapping(uint=>bool)public isIdUsed;

    //events
    event ProjectCreated(uint indexed projectId,address indexed creater,string name,string description,uint FundingGoal,uint deadline );
    event ProjectFunded(uint indexed projectId,address indexed contributer,uint amount);
    event FundsWithdrawn(uint indexed projectId,address indexed withdrawer,uint amount , string withdrawerType);
    event NewDeadline(uint indexed projectId,uint newDeadline);
    //withdrawer type = "user" , ="admin"

    //create project by a creator
    //external public internal private
    function createProject(
        //We use memory as dynamic sized string or array for dynamic allocation of memory
            string memory _name,
            string memory _description,
            uint _fundingGoal,
            uint _durationSeconds,
            uint _id
        )external{
        require(!isIdUsed[_id],"Project Id is already used");
        isIdUsed[_id]=true;
        projects[_id]=Project({
            creator:msg.sender,
            name:_name,
            highestFunder:msg.sender,
            highestFunding:0,
            description:_description,
            fundingGoal:_fundingGoal,
            deadline:block.timestamp+_durationSeconds,
            amountRaised:0,
            funded:false
        });
        keys.push(_id);
        totalnoOfProjects++;
        noOfProjAddWise[msg.sender]++;
        emit ProjectCreated(
            _id,
            msg.sender,
            _name,
            _description,
            _fundingGoal,
            block.timestamp+_durationSeconds
        );


    }

    //function = external means it can be called any one.
    function fundProject(uint _projectId)external payable{
        Project storage project=projects[_projectId];
        require(block.timestamp<=project.deadline,"Project deadline is already passed.");
        require(!project.funded,"Project is already funded");
        require(msg.value>0,"Must sent some value of ether.");
        if (msg.value>project.highestFunding) {
            project.highestFunding=msg.value;
            project.highestFunder=msg.sender;
        }
        project.amountRaised=project.amountRaised+(msg.value * 95)/100;
        _commision.transfer((msg.value*5)/100);
        contributions[_projectId][msg.sender]=msg.value;
        emit ProjectFunded(_projectId,msg.sender,msg.value);
        if(project.amountRaised>=project.fundingGoal){
            project.funded=true;
            totalSuccessfullyFundedProj++;
        }

    }

    //user withdraw funds
    function userWithdrawFunds(uint _projectId)external payable{
        Project storage project=projects[_projectId];
        require(project.amountRaised<project.fundingGoal,"Funding goal is reached , user cant withdraw");
        uint fundContributed=contributions[_projectId][msg.sender];
        payable(msg.sender).transfer(fundContributed);
    }

    //admin withdraw funds
    function adminWithdrawFunds(uint _projectId)external payable{
        Project storage project=projects[_projectId];
        uint totalFunding = project.amountRaised;
        require(project.funded,"Funding is not sufficient");
        require(project.creator==msg.sender,"Only project admin can withsraw");
        require(project.deadline<=block.timestamp,"Deadline for project is not reached");
        payable(msg.sender).transfer(totalFunding);
    }

    //Setting a new deadline
    function setDeadline(uint _projectId,uint _newDeadline)external payable{
        Project storage project = projects[_projectId];
        require(project.creator==msg.sender,"Only Creator can Change the Deadline");
        require(_newDeadline>block.timestamp,"Deadline is already passed.");
        project.deadline=_newDeadline;
        emit NewDeadline(_projectId,_newDeadline);
    }
    
    //Tract total failed to funded projects
    function totalFaildedToFundProj()public view returns(uint){
        uint count=0;
        for(uint i =0;i<keys.length;i++){
          if(block.timestamp>projects[keys[i]].deadline && projects[keys[i]].amountRaised<projects[keys[i]].fundingGoal){
            count++;
          }
        }
        return count;
    }
}