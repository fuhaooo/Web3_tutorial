// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

//1.收款函数（合约可以收集资产）
//2.记录投资人并且查看
//3.在锁定期内，达到目标值，生产商可以提款
//4.在锁定期内，没有达到目标值，投资人可以退款

contract FundMe {
    
    mapping (address => uint256) public fundersToAmount; 

    uint256 MINIMUM_VALUE = 100 * 10 ** 18;//USD

    AggregatorV3Interface public dataFeed;

    uint256 constant TARGET = 1000 * 10 ** 18;

    address public owner;

    uint256 deplomentTimestamp;
    uint256 lockTime;

    address internal erc20Addr;

    bool public getFundSuccess = false;

    event FundWithdrawByOwner(uint256);
    event RefundByFunder(address, uint256);

    constructor(uint256 _lockTime, address dataFeedAddr) {
        //sepolia test
        dataFeed = AggregatorV3Interface(dataFeedAddr);
        owner = msg.sender;
        deplomentTimestamp = block.timestamp;
        lockTime = _lockTime;
    }

    function fund() external payable {
        require(convertEthToUsd(msg.value) >= MINIMUM_VALUE, "Send more ETH");
        require(block.timestamp < deplomentTimestamp + lockTime, "Window is closed");
        fundersToAmount[msg.sender] = msg.value;
    }

    /**
     * Returns the latest answer.
     */
    function getChainlinkDataFeedLatestAnswer() public view returns (int) {
        // prettier-ignore
        (
            /* uint80 roundID */,
            int answer,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();
        return answer;
    }

    function convertEthToUsd(uint256 ethAmount) internal view returns (uint256) {
        uint256 ethPrice = uint256(getChainlinkDataFeedLatestAnswer());
        return ethAmount * ethPrice / (10 ** 8);
        // ETH / USD precision = 10 ** 8
        // X / ETH precision = 10 ** 18
    }

    function getFund() external windowClosed onlyOwner{
        require(convertEthToUsd(address(this).balance) >= TARGET, "Target is not reached"); 

        //transfer: transfer ETH and revert if tx failed
        // payable(msg.sender).transfer(address(this).balance);

        //send: transfer ETH and return false if failed
        // bool success = payable(msg.sender).send(address(this).balance);
        // require(success, "tx failed");

        //call: transfer ETH with data return value of function and bool
        bool success;
        uint256 balance = address(this).balance;
        (success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Transfer tx failed");
        fundersToAmount[msg.sender] = 0;
        getFundSuccess = true;
        // emit event
        emit FundWithdrawByOwner(balance);
    }

    function refund() external windowClosed{
        require(convertEthToUsd(address(this).balance) < TARGET, "Target is reached"); 
        require(fundersToAmount[msg.sender] != 0, "There is not fund for you");
        bool success;
        uint256 balance = fundersToAmount[msg.sender];
        (success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Transfer tx failed");
        fundersToAmount[msg.sender] = 0;
        emit RefundByFunder(msg.sender, balance);
    }

    function setFunderToAmount(address funder, uint256 amountToUpdate) external {
        require(msg.sender == erc20Addr, "You do not have permisson to call this function");
        fundersToAmount[funder] = amountToUpdate;
    }

    function setErc20Addr(address _erc20Addr) public onlyOwner {
        erc20Addr = _erc20Addr;
    }

    function transferOwnership(address newOwner) public {
        owner = newOwner;
        require(msg.sender == owner, "This function can only be called by owner");
    }

    modifier windowClosed() {
        require(block.timestamp >= deplomentTimestamp + lockTime, "Window is not closed");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner,  "This function can only be called by owner");
        _;
    }
}