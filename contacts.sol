// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NFTMarketplace is ReentrancyGuard {
    using SafeMath for uint256;

    // Structure to store listing information
    struct Listing {
        address seller;
        uint256 price;
        bool isActive;
    }

    // Mapping from NFT contract address => token ID => Listing
    mapping(address => mapping(uint256 => Listing)) public listings;

    // Events
    event NFTListed(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );
    
    event NFTSold(
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address buyer,
        uint256 price
    );

    // Function to list NFT for sale
    function listNFT(
        address _nftContract,
        uint256 _tokenId,
        uint256 _price
    ) external nonReentrant {
        require(_price > 0, "Price must be greater than zero");
        
        IERC721 nftContract = IERC721(_nftContract);
        require(nftContract.ownerOf(_tokenId) == msg.sender, "Not the NFT owner");
        require(
            nftContract.isApprovedForAll(msg.sender, address(this)),
            "Contract not approved to manage NFT"
        );

        listings[_nftContract][_tokenId] = Listing({
            seller: msg.sender,
            price: _price,
            isActive: true
        });

        emit NFTListed(_nftContract, _tokenId, msg.sender, _price);
    }

    // Function to buy NFT
    function buyNFT(
        address _nftContract,
        uint256 _tokenId
    ) external payable nonReentrant {
        Listing memory listing = listings[_nftContract][_tokenId];
        require(listing.isActive, "NFT not listed for sale");
        require(msg.value == listing.price, "Incorrect price");
        require(msg.sender != listing.seller, "Seller cannot buy their own NFT");

        // Remove listing
        listings[_nftContract][_tokenId].isActive = false;

        // Transfer NFT to buyer
        IERC721(_nftContract).safeTransferFrom(
            listing.seller,
            msg.sender,
            _tokenId
        );

        // Transfer payment to seller
        (bool success, ) = payable(listing.seller).call{value: msg.value}("");
        require(success, "Failed to send payment to seller");

        emit NFTSold(
            _nftContract,
            _tokenId,
            listing.seller,
            msg.sender,
            listing.price
        );
    }
}