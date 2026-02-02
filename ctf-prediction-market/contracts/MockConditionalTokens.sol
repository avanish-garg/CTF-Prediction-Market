// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IConditionalTokens.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

/**
 * @title MockConditionalTokens
 * @dev A simplified mock implementation of ConditionalTokens for testing
 */
contract MockConditionalTokens is ERC1155, IConditionalTokens {
    mapping(bytes32 => bool) public conditions;
    mapping(bytes32 => address) public conditionOracles;
    mapping(bytes32 => uint256) public conditionOutcomeSlots;
    mapping(bytes32 => uint256[]) public conditionPayouts;
    mapping(bytes32 => bool) public conditionResolved;

    constructor() ERC1155("") {}

    function prepareCondition(
        address oracle,
        bytes32 questionId,
        uint256 outcomeSlotCount
    ) external override {
        bytes32 conditionId = _getConditionId(oracle, questionId, outcomeSlotCount);
        require(!conditions[conditionId], "Condition already prepared");
        conditions[conditionId] = true;
        conditionOracles[conditionId] = oracle;
        conditionOutcomeSlots[conditionId] = outcomeSlotCount;
    }

    function splitPosition(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256[] calldata partition,
        uint256 amount
    ) external override {
        require(conditions[conditionId], "Condition not prepared");
        require(!conditionResolved[conditionId], "Condition already resolved");
        
        // Transfer collateral from caller
        require(collateralToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        // Mint ERC1155 tokens for each partition
        for (uint256 i = 0; i < partition.length; i++) {
            uint256 positionId = getPositionId(address(collateralToken), getCollectionId(parentCollectionId, conditionId, partition[i]));
            _mint(msg.sender, positionId, amount, "");
        }
    }

    function redeemPositions(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256[] calldata indexSets
    ) external override {
        require(conditionResolved[conditionId], "Condition not resolved");
        
        uint256 totalRedeemable = 0;
        
        for (uint256 i = 0; i < indexSets.length; i++) {
            bytes32 collectionId = getCollectionId(parentCollectionId, conditionId, indexSets[i]);
            uint256 positionId = getPositionId(address(collateralToken), collectionId);
            uint256 balance = balanceOf(msg.sender, positionId);
            
            if (balance > 0) {
                // Calculate redeemable amount based on payout
                uint256 indexSet = indexSets[i];
                require(indexSet <= conditionOutcomeSlots[conditionId], "Invalid index set");
                
                // For binary market: if payout is [0, 1] and indexSet is 2 (NO), redeemable = 0
                // If payout is [1, 0] and indexSet is 1 (YES), redeemable = balance
                uint256 payoutIndex = indexSet - 1; // Convert to 0-indexed
                if (payoutIndex < conditionPayouts[conditionId].length && conditionPayouts[conditionId][payoutIndex] > 0) {
                    totalRedeemable += balance;
                }
                
                _burn(msg.sender, positionId, balance);
            }
        }
        
        if (totalRedeemable > 0) {
            require(collateralToken.transfer(msg.sender, totalRedeemable), "Redeem transfer failed");
        }
    }

    function reportPayouts(bytes32 questionId, uint256[] calldata payouts) external override {
        // Find condition by questionId - we need to find which condition matches
        // For simplicity, we'll iterate through a limited set or use a mapping
        // In a real implementation, you'd track questionId -> conditionId
        // For this mock, we'll require the oracle to match and use outcomeSlotCount from payouts
        uint256 outcomeSlotCount = uint256(payouts.length);
        bytes32 conditionId = _getConditionId(msg.sender, questionId, outcomeSlotCount);
        require(conditions[conditionId], "Condition not found");
        require(msg.sender == conditionOracles[conditionId], "Only oracle can report");
        require(!conditionResolved[conditionId], "Already resolved");
        
        conditionPayouts[conditionId] = payouts;
        conditionResolved[conditionId] = true;
    }

    function _getConditionId(
        address oracle,
        bytes32 questionId,
        uint256 outcomeSlotCount
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(oracle, questionId, outcomeSlotCount));
    }

    function getConditionId(
        address oracle,
        bytes32 questionId,
        uint256 outcomeSlotCount
    ) external pure override returns (bytes32) {
        return _getConditionId(oracle, questionId, outcomeSlotCount);
    }

    function getCollectionId(
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256 indexSet
    ) public view override returns (bytes32) {
        if (parentCollectionId == bytes32(0)) {
            return keccak256(abi.encodePacked(conditionId, indexSet));
        }
        return keccak256(abi.encodePacked(parentCollectionId, conditionId, indexSet));
    }

    function getPositionId(
        address collateralToken,
        bytes32 collectionId
    ) public view override returns (uint256) {
        return uint256(keccak256(abi.encodePacked(collateralToken, collectionId)));
    }
}
