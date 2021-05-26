
// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

contract WETH {
    function deposit() public payable;
    function withdraw(uint wad) public;
    function totalSupply() public view returns (uint);
    function approve(address guy, uint wad) public returns (bool);
    function transfer(address dst, uint wad) public returns (bool);
    function transferFrom(address src, address dst, uint wad) public returns (bool);
}
