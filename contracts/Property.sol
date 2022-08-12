//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

//metadataUri=ipfs://QmNniGfFDw43dRsX9JxYTafyLx9gybkupvn52KpXsQvYW5

/// @notice Represents a real estate property in the system.
contract Property is ERC721URIStorage {
    uint256 tokenId;
    constructor(string memory name_, string memory symbol_, string memory metadataUri_) ERC721(name_, symbol_) {
        // only one token will be created in this ERC721, which is the property itself
        tokenId = 0;
        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, metadataUri_);
    }
}