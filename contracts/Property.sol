//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract Property is ERC721URIStorage{
    constructor() ERC721("HITMOTS", "House In The Middle Of The Street") {
       // TODO: set URI here and mint
    }
}