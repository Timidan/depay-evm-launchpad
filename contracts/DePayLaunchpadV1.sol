// SPDX-License-Identifier: MIT

pragma solidity >=0.8.6 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

contract DePayLaunchpadV1 is Ownable {
  
  using SafeMath for uint;
  using SafeERC20 for ERC20;

  // The address of the token to be launched
  address public launchedToken;

  // The address of the token to be accepted as payment for claiming the launched token
  address public paymentToken;

  // Total amount of launched tokens to be claimable by others
  uint256 public totalClaimable;

  // Total amount of tokens already claimed
  uint256 public totalClaimed;

  // Time the claiming perioud ends
  uint256 public endTime;

  // Price represents amount of tokens required to pay (paymentToken) per token claimed (launchedToken)
  uint256 public price;

  // Stores all whitelisted address
  mapping (address => bool) public whitelist;

  // Stores all claims per address
  mapping (address => uint256) public claims;

  // Limit executions to uninitalized launchpad state only
  modifier onlyUninitialized() {
    require(
      launchedToken == address(0),
      "You can only initialize a launchpad once!"
    );
    _;
  }

  // Initalizes the launchpad and ensures that launchedToken and paymentToken are set.
  // Makes sure you cant initialize the launchpad without any claimable token amounts.
  function init(
    address _launchedToken,
    address _paymentToken
  ) external onlyUninitialized onlyOwner returns(bool) {
    launchedToken = _launchedToken;
    paymentToken = _paymentToken;
    totalClaimable = ERC20(launchedToken).balanceOf(address(this));
    require(totalClaimable > 0, "You need to initalize the launchpad with claimable tokens!");
    return true;
  }

  // Limit executions to initalized launchpad state only
  modifier onlyInitialized() {
    require(
      totalClaimable > 0,
      "Launchpad has not been initialized yet!"
    );
    _;
  }

  // Limit executions to unstarted launchpad state only
  modifier onlyUnstarted() {
    require(
      endTime == 0,
      "You can only start a launchpad once!"
    );
    _;
  }

  // Starts the claiming process.
  // Makes sure endTime is in the future and not to far in the future.
  // Also makes sure that the price per launched token is set properly.
  function start(
    uint256 _endTime,
    uint256 _price
  ) external onlyOwner onlyInitialized onlyUnstarted returns(bool) {
    require(_endTime > block.timestamp, "endTime needs to be in the future!");
    require(_endTime < (block.timestamp + 12 weeks), "endTime needs to be less than 12 weeks in the future!");
    endTime = _endTime;
    price = _price;
    return true;
  }

  // Whitelist address (enables them to claim launched token)
  function setWhitelist(
    address _address,
    bool status
  ) external onlyOwner returns(bool) {
    whitelist[_address] = status;
    return true;
  }

  // Limit executions to launchpad in progress only
  modifier onlyInProgress() {
    require(
      endTime > 0,
      "Launchpad has not been started yet!"
    );
    require(
      endTime > block.timestamp,
      "Launchpad has been finished!"
    );
    _;
  }

  // Claims a token allocation for claimedAmount.
  // Makes sure that the payment for the allocation is sent along and stored in the smart contract (payedAmount).
  // Also ensures that its not possible to claim more than totalClaimable.
  function claim(
    address forAddress,
    uint256 claimedAmount
  ) external onlyInProgress returns(bool) {
    require(whitelist[forAddress], 'Address has not been whitelisted for this launch!');
    uint256 payedAmount = claimedAmount.div(10**ERC20(paymentToken).decimals()).mul(price);
    ERC20(paymentToken).safeTransferFrom(msg.sender, address(this), payedAmount);
    claims[forAddress] = claims[forAddress].add(claimedAmount);
    return true;
  }
}
