// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import './ERC721A.sol';

contract Thinkr is Ownable, ERC721A, ReentrancyGuard{
    using SafeMath for uint256;
    using Strings for uint256;

    uint256 public immutable MAX_TOKENS = 10000;
    uint256 public price = 0.01 ether;
    uint256 public allowlistPrice = 0.01 ether;

    bool public publicSaleStarted = false;
    bool public presaleStarted = false;
    bool public revealed = false;

    uint256 public maxPerWallet = 5;
    uint256 public maxPerAllow = 2;

    string public baseURI;
    string public baseExtension = ".json";
    string public notRevealedURI;

  //Stores addresses for allow list
  mapping(address => uint256) public allowlist;
  //This stores number of mints per wallet address during publicSale
  mapping(address => uint256) private _walletMints;

  //------------------------------------------------------------
  //come back, see if we want to cut down code
  constructor(
    string memory initBaseURI_,
    string memory initNotRevealedURI_

  ) ERC721A("Thinkr", "THKR") {
    baseURI = initBaseURI_;
    notRevealedURI = initNotRevealedURI_;
     //This send X amount tokens to the wallet that deployed the contract
      _safeMint(msg.sender, 10);
  }
//------------------------------------------------------------

  function togglePresaleStarted() external onlyOwner {
        presaleStarted = !presaleStarted;
    }

  function togglePublicSaleStarted() external onlyOwner {
        publicSaleStarted = !publicSaleStarted;
    }

 function setBaseURI(string calldata newBaseURI) external onlyOwner {
    baseURI = newBaseURI;
  }

  function reveal(bool _state) public onlyOwner {
      revealed = _state;
  }

  function setMaxPerWallet(uint256 _newMaxPerWallet) external onlyOwner {
      maxPerWallet = _newMaxPerWallet;
  }
  
  function setMaxPerAllow(uint256 _newMaxPerAllow) external onlyOwner {
      maxPerAllow = _newMaxPerAllow;
  }
 
 function setNotRevealedURI(string memory _notRevealedURI) external onlyOwner {
    notRevealedURI = _notRevealedURI;
  }

  function setBaseExtension(string memory _newBaseExtension) external onlyOwner {
    baseExtension = _newBaseExtension;
  }
  
  function setPrice(uint256 _newPrice) external onlyOwner {
    price = _newPrice * (1 ether);
  }

  function setAllowPrice(uint256 _newPrice) external onlyOwner {
    allowlistPrice = _newPrice * (1 ether);
  }

  function getMintSlots(address user)public view returns (uint256) {
    require(allowlist[user] > 0, "not eligible for allowlist mint");
    uint256 mintSlots = allowlist[user];
    return mintSlots;
  }

  function seedAllowlist(address[] memory addresses) external onlyOwner
  {
    require(
      addresses.length > 0,
      "addresses cannot be empty"
    );
    for (uint256 i = 0; i < addresses.length; i++) {
      allowlist[addresses[i]] = maxPerAllow;
    }
  }

  function withdrawMoney() external onlyOwner nonReentrant {
    uint256 balance = address(this).balance;
    require(balance > 0, "Insufficent balance");
    (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
    require(success, "Transfer failed.");
  }

  
//------------------------------------------------------------
 //Check to see what token# we want to start at! 
function _startTokenId() internal pure override returns (uint256) {
        return 1;
}

function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;

}

//------------------------------------------------------------
function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId),"ERC721Metadata: Nonexistent token");

        //Added for NFT reveal
        if (revealed == false){
            return (notRevealedURI);
        }   

        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension)) : '';
}

function numberMinted(address owner) public view returns (uint256) {
    return _numberMinted(owner);
}

function getOwnershipData(uint256 tokenId) external view returns (TokenOwnership memory){
    return _ownershipOf(tokenId);
}

modifier callerIsUser() {
    require(tx.origin == msg.sender, "The caller is another contract");
    _;
}

//AllowlistMint allows people to choose to mint either 1 or 2 
function allowlistMint(uint256 tokens) external payable callerIsUser {
    require(presaleStarted, "Presale has not started");
    require(tokens > 0 && tokens <= maxPerAllow, "Must mint at least one token and not more than 2");
    uint256 mintPrice = allowlistPrice;
    require(mintPrice != 0, "allowlist sale has not begun yet");
    require(allowlist[msg.sender] > 0, "not eligible for allowlist mint");
    uint256 mintSlots = allowlist[msg.sender];
    require(tokens <= mintSlots, "You cannot mint this amount");
    require(totalSupply() + tokens <= MAX_TOKENS, "reached max supply");
    require(msg.value == mintPrice * tokens,"ETH amount is incorrect");
    allowlist[msg.sender] = allowlist[msg.sender] - tokens;
    _safeMint(msg.sender, tokens);
}

/// Public Sale mint function
/// @param tokens number of tokens to mint
/// @dev reverts if any of the public sale preconditions aren't satisfied
function mint(uint256 tokens) external payable callerIsUser {
    require(publicSaleStarted, "Public sale has not started");
    require(tokens <= maxPerWallet, "Cannot purchase this many tokens in a transaction");
    require(_walletMints[_msgSender()] + tokens <= maxPerWallet, "Limit for this wallet reached");
    require(totalSupply() + tokens <= MAX_TOKENS, "Minting would exceed max supply");
    require(tokens > 0, "Must mint at least one token");
    require(price * tokens == msg.value, "ETH amount is incorrect");

    _walletMints[_msgSender()] += tokens;
    _safeMint(_msgSender(), tokens);
}
}