// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TimeLockedWallet is Ownable {
    using SafeERC20 for IERC20;

    struct TokenLock {
        address recipient;
        uint256 startTime;
        uint256 duration;
        uint256 amount;
        bool withdrawn;
    }

    mapping(address => TokenLock[]) public tokenLocks;
    mapping(address => uint256) public fees;

    uint256 public dailyCost;
    address public feeReceiver;

    constructor(uint256 _dailyCost, address _feeReceiver) {
        dailyCost = _dailyCost;
        feeReceiver = _feeReceiver;
    }

    function addTokenLock(
        address _token,
        address _recipient,
        uint256 _duration,
        uint256 _amount
    ) external {
        require(_recipient != address(0), "Invalid recipient address");
        require(_amount > 0, "Amount must be greater than 0");

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        uint256 fee = calculateFee(_duration, _amount);
        fees[_token] += fee;

        uint256 amountAfterFee = _amount - fee;
        IERC20(_token).safeTransfer(feeReceiver, fee);

        tokenLocks[_token].push(
            TokenLock({
                recipient: _recipient,
                startTime: block.timestamp,
                duration: _duration,
                amount: amountAfterFee,
                withdrawn: false
            })
        );
    }

    function withdrawToken(address _token, uint256 _index) external {
        TokenLock storage tokenLock = tokenLocks[_token][_index];
        require(
            !tokenLock.withdrawn,
            "Token has already been withdrawn"
        );
        require(
            block.timestamp >= tokenLock.startTime + tokenLock.duration,
            "Tokens are still locked"
        );

        tokenLock.withdrawn = true;
        IERC20(_token).safeTransfer(tokenLock.recipient, tokenLock.amount);
    }

    function calculateFee(uint256 _duration, uint256 _amount)
        internal
        view
        returns (uint256)
    {
        uint256 days = _duration / (1 days);
        uint256 totalCost = dailyCost * days;
        return (_amount * totalCost) / 1e18;
    }

    function setDailyCost(uint256 _dailyCost) external onlyOwner {
        dailyCost = _dailyCost;
    }

    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        feeReceiver = _feeReceiver;
    }
}