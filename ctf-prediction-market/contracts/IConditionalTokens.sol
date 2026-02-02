// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IConditionalTokens {
    // Market prepare karne ke liye
    function prepareCondition(
        address oracle,
        bytes32 questionId,
        uint256 outcomeSlotCount
    ) external;

    // Tokens mint karne ke liye (Splitting)
    function splitPosition(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256[] calldata partition,
        uint256 amount
    ) external;

    // Jeetne ke baad paisa lene ke liye (Merging/Redeeming)
    function redeemPositions(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256[] calldata indexSets
    ) external;

    // Result declare karne ke liye (Oracle Only)
    function reportPayouts(bytes32 questionId, uint256[] calldata payouts) external;
    
    // Condition ID calculate karne ka helper
    function getConditionId(
        address oracle,
        bytes32 questionId,
        uint256 outcomeSlotCount
    ) external pure returns (bytes32);

    // Position ID nikalne ke liye
    function getCollectionId(
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256 indexSet
    ) external view returns (bytes32);
    
    function getPositionId(
        address collateralToken,
        bytes32 collectionId
    ) external view returns (uint256);
}