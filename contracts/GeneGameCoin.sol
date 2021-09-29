// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
    @dev Gene Game Coin
 */
contract GeneGameCoin is Ownable, ERC20Burnable {
    using SafeMath for uint256;

    IERC20  public      collateral;
    uint256 public      exchangeRate;   // how many collateral needed to get 1 GGC
    address public      feeReceiver;
    uint256 public      feeRate;
    uint256 constant    FEE_RATE_BASE   = 100000000; // 100000000 as 100%
    uint256 constant    FEE_RATE_MAX    = 5000000;   // 5% at most

    event FeeReceiverUpdate(address oldReceiver, address newReceiver);
    event FeeRateUpdate(uint256 oldRate, uint256 newRate);
    event Minting(address sender, address account, uint256 amount, uint256 fee);
    event Burning(address sender, address account, uint256 amount);

    modifier onlyReceiver() {
        require(msg.sender == feeReceiver, "GenechainGameCoin: only receiver can do this");
        _;
    }

    /**
        @dev constructor of GGC
        @param _collateral      collateral token address
        @param _exchangeRate    how many collateral needed to get 1 GGC
        @param _feeRate         fee rate charged by protocol
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _collateral,
        uint256 _exchangeRate,
        uint256 _feeRate
    ) ERC20(_name, _symbol) {
        collateral = IERC20(_collateral);
        exchangeRate = _exchangeRate;
        updateFeeRate(_feeRate);
        feeReceiver = owner();
    }

    /**
        @dev GGC is not dividable with 0 decimal
     */
    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    /**
        @dev update feeReceiver
        @param receiver new fee receiver
     */
    function updateReceiver(address receiver) onlyReceiver public {
        require(
            receiver != feeReceiver, 
            "GeneGameCoin: new fee receiver is the same as the old"
        );
        emit FeeReceiverUpdate(feeReceiver, receiver);
        feeReceiver = receiver;
    }

    /**
        @dev update feeRate
        @param rate new fee rate
     */
    function updateFeeRate(uint256 rate) onlyOwner public {
        require(
            rate <= FEE_RATE_MAX, 
            "GeneGameCoin: fee rate too large"
        );
        emit FeeRateUpdate(feeRate, rate);
        feeRate = rate;
    }

    /**
        @dev calc how many collateral is needed to get a specified amount of GGC
     */
    function collateralNeeded(uint256 amount) public view virtual returns (uint256) {
        uint256 collateralAmount = amount.mul(exchangeRate);
        uint256 fee = collateralAmount.mul(feeRate).div(FEE_RATE_BASE);
        return collateralAmount.add(fee);
    }

    /**
        @dev mint GGC tokens by collateral
        @param account the account to mint to
        @param amount the amount to mint    
     */
    function mint(address account, uint256 amount) public virtual {
        // calculate collateral by rate
        uint256 collateralAmount = amount.mul(exchangeRate);
        uint256 feeAmount = 0;
        if (feeRate > 0) {
            feeAmount = collateralAmount.mul(feeRate).div(FEE_RATE_BASE);
            require(
                feeAmount > 0,
                "GeneGameCoin: amount too small"
            );
            // charge fee
            collateral.transferFrom(msg.sender, feeReceiver, feeAmount);
        }
        // charge collateral
        collateral.transferFrom(msg.sender, address(this), collateralAmount);
        _mint(account, amount);
        emit Minting(msg.sender, account, amount, feeAmount);
    }

    /**
        @dev burn GGC tokens from caller
        @param amount the amount to burn
     */
    function burn(uint256 amount) public virtual override {
        super.burn(amount);
        collateral.transfer(msg.sender, amount.mul(exchangeRate));
        emit Burning(msg.sender, msg.sender, amount);
    }

    /**
        @dev burn GGC tokens from account and get it's collateral
        @param account the account to burn from
        @param amount the amount to burn
     */
    function burnFrom(address account, uint256 amount) public override {
        super.burnFrom(account, amount);
        collateral.transfer(msg.sender, amount.mul(exchangeRate));
        emit Burning(msg.sender, account, amount);
    }
}
