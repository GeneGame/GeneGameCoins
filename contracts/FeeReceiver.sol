// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./GeneGameCoin.sol";

/**
    @dev FeeReceiver of GGC
 */

contract FeeReceiver {
    using SafeMath for uint256;
    
    GeneGameCoin public GGC;
    uint256 constant TOTAL_SHARE_COUNT = 1000000;
    uint256 unredeemed;
    uint256 totalReceived;

    struct HolderInfo {
        address account;
        uint256 share;
        uint256 redeemable;
    }

    HolderInfo[] holders;

    mapping(address => address[]) public receiverUpdateProposal;

    event EventReceiverUpdateProposed(address by, address receiver);
    event EventReceiverUpdated(address receiver);

    modifier onlyHolder() {
        bool found;
        for (uint256 i; i < holders.length; i++) {
            if (msg.sender == holders[i].account) {
                found = true;
                break;
            }
        }
        require(found, "FeeReceiver: not a holder");
        _;
    }

    /**
        @dev constructor of FeeReceiver
        @param _GGC        GeneGameCoin address
        @param _holders    holder address list
        @param _shares     holder share ratios
     */
    constructor(
        address _GGC,
        address[] memory _holders,
        uint256[] memory _shares
    ) {
        require(_GGC != address(0), "FeeReceiver: GGC should be specified");
        require(_holders.length > 0, "FeeReceiver: at least one share holder is needed");
        require(_holders.length == _shares.length, "FeeReceiver: holder and share count not match");

        GGC = GeneGameCoin(_GGC);

        uint256 totalShares = 0;
        for (uint256 i; i < _holders.length; i++) {
            totalShares = totalShares.add(_shares[i]);
        }
        require(totalShares == TOTAL_SHARE_COUNT, "FeeReceiver: invalid share config");
        for (uint256 i; i < _holders.length; i++) {
            HolderInfo memory holder;
            holder.account = _holders[i];
            holder.share = _shares[i];
            holders.push(holder);
        }
    }
    
    /**
        @dev get info of a holder
     */
    function holderInfo(address account) public view returns (uint256 share, uint256 redeemable) {
        for (uint256 i; i < holders.length; i++) {
            if (account == holders[i].account) {
                return (holders[i].share, holders[i].redeemable);
            }
        }    
        return (0, 0);
    }

    /**
        @dev split all pending reward
     */
    function splitPending() public {
        uint256 totalAmount = GGC.collateral().balanceOf(address(this)).sub(unredeemed);
        if (totalAmount == 0) {
            return;
        }
        uint256 splited;
        for (uint256 i; i < holders.length; i++) {
            uint256 holderGet = totalAmount.mul(holders[i].share).div(TOTAL_SHARE_COUNT);
            holders[i].redeemable = holders[i].redeemable.add(holderGet);
            splited = splited.add(holderGet);
        }
        totalReceived = totalReceived.add(splited);
        unredeemed = unredeemed.add(splited);
    }

    /**
        @dev total fee got since start
     */
    function totalFeeGot() public view returns (uint256) {
        return GGC.collateral().balanceOf(address(this)).sub(unredeemed).add(totalReceived);
    }

    /**
        @dev unspilt fee amount
     */
    function unsplitAmount() public view returns (uint256) {
        return GGC.collateral().balanceOf(address(this)).sub(unredeemed);
    }

    /**
        @dev redeem pending reward share
        @param to receiver of reward
        @param amount amount to redeem
     */
    function redeem(address to, uint256 amount) onlyHolder public {
        for (uint256 i = 0; i < holders.length; i++) {
            if (holders[i].account == msg.sender) {
                require(holders[i].redeemable >= amount, "FeeReceiver: insufficient amount to redeem");
                holders[i].redeemable = holders[i].redeemable.sub(amount);
                unredeemed = unredeemed.sub(amount);
                GGC.collateral().transfer(to, amount);
                return;
            }
        }
        require(false, "FeeReceiver: redeem fail");
    }

    /**
        @dev redeem all pending reward share
        @param to receiver of reward
     */
    function redeemAll(address to) onlyHolder public {
        splitPending();
        for (uint256 i = 0; i < holders.length; i++) {
            if (holders[i].account == msg.sender) {
                redeem(to, holders[i].redeemable);
                break;
            }
        }
    }

    /**
     * @dev update receiver to a new account.
     * Can only be called by the current owner.
     */
    function proposeToUpdateReceiver(address receiver) onlyHolder public {
        require(receiver != address(0), "FeeReceiver: new owner is the zero address");
        // no proposal yet
        if (receiverUpdateProposal[receiver].length != 0) {
            // check if already proposed
            for (uint256 i = 0; i < receiverUpdateProposal[receiver].length; i++) {
                require(receiverUpdateProposal[receiver][i] != msg.sender, "FeeReceiver: alredy proposed");
            }
        }
        receiverUpdateProposal[receiver].push(msg.sender);
        emit EventReceiverUpdateProposed(msg.sender, receiver);
        if (receiverUpdateProposal[receiver].length == holders.length) {
            GGC.updateReceiver(receiver);
            emit EventReceiverUpdated(receiver);
        }
    }
}
