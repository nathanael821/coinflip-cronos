// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./Ownable.sol";

contract CoinFlip is Ownable {
    uint256 private contractBalance;

    struct Temp {
        uint256 id;
        uint256 result;
        address playerAddress;
    }

    struct PlayerByAddress {
        uint256 balance;
        uint256 betAmount;
        uint256 betChoice;
        address playerAddress;
        bool betOngoing;
    }

    mapping(address => PlayerByAddress) public playersByAddress; //to check who is the player
    mapping(uint256 => Temp) public temps; //to check who is the sender of a pending bet by Id

    event DepositToContract(address user, uint256 depositAmount, uint256 newBalance);
    event Withdrawal(address player, uint256 amount);
    event BetResult(address indexed player, bool victory, uint256 amount);

    constructor() payable initCosts(10 ether) {
        contractBalance += msg.value;
    }

    modifier initCosts(uint256 initCost) {
        require(msg.value >= initCost, "Contract needs some ETH.");
        _;
    }

    modifier betConditions() {
        require(msg.value >= 0.001 ether, "Insuffisant amount, please increase your bet!");
        require(msg.value <= getContractBalance() / 2, "Can't bet more than half the contract's balance!");
        require(!playersByAddress[msg.sender].betOngoing, "Bet already ongoing with this address");
        _;
    }

    function bet(uint256 _betChoice) public payable betConditions {
        require(_betChoice == 0 || _betChoice == 1, "Must be either 0 or 1");

        playersByAddress[msg.sender].playerAddress = msg.sender;
        playersByAddress[msg.sender].betChoice = _betChoice;
        playersByAddress[msg.sender].betOngoing = true;
        playersByAddress[msg.sender].betAmount = msg.value;
        contractBalance += playersByAddress[msg.sender].betAmount;

        uint8 randomResult = random();
        bool win = false;
        uint256 amountWin = 0;

        if (playersByAddress[msg.sender].betChoice == randomResult) {
            win = true;
            amountWin = playersByAddress[msg.sender].betAmount * 2;
            playersByAddress[msg.sender].balance = playersByAddress[msg.sender].balance + amountWin;
            contractBalance -= amountWin;
        }

        emit BetResult(msg.sender, win, amountWin);
        playersByAddress[msg.sender].betAmount = 0;
        playersByAddress[msg.sender].betOngoing = false;
    }

    function random() public view returns (uint8) {
        return uint8(uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp))) % 2);
    }

    function deposit() external payable {
        require(msg.value > 0);
        contractBalance += msg.value;
        emit DepositToContract(msg.sender, msg.value, contractBalance);
    }

    function withdrawPlayerBalance() external {
        require(msg.sender != address(0), "This address doesn't exist.");
        require(playersByAddress[msg.sender].balance > 0, "You don't have any fund to withdraw.");
        require(!playersByAddress[msg.sender].betOngoing, "this address still has an open bet.");

        uint256 amount = playersByAddress[msg.sender].balance;
        payable(msg.sender).transfer(amount);
        delete (playersByAddress[msg.sender]);

        emit Withdrawal(msg.sender, amount);
    }

    function withdrawContractBalance() external onlyOwner {
        _payout(payable(msg.sender));
    }

    function getPlayerBalance() external view returns (uint256) {
        return playersByAddress[msg.sender].balance;
    }

    function getContractBalance() public view returns (uint256) {
        return contractBalance;
    }

    function _payout(address payable to) private returns (uint256) {
        require(contractBalance != 0, "No funds to withdraw");

        uint256 toTransfer = address(this).balance;
        contractBalance = 0;
        to.transfer(toTransfer);
        return toTransfer;
    }
}
