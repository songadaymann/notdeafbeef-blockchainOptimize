// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title NotDeafbeef721
 * @notice Deafbeef-inspired ERC-721 where each token stores on-chain pointers (tx hashes) 
 *         to UTF-8 ARM64 assembly source code. Audio-visual NFTs are reconstructed off-chain 
 *         using the on-chain code + per-token seed.
 *         
 *         Features:
 *         - 512 free mints (gas only) 
 *         - Pure ARM64 assembly audio + visual generation
 *         - Deterministic reproduction from transaction hashes
 *         - Complete source code transparency on-chain
 *         - deafbeef-style permanence and verifiability
 */
contract NotDeafbeef721 is ERC721, AccessControl {
    // --- Roles ---
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    struct SeriesStruct {
        bytes32[25] codeLocations;        // TX hashes containing UTF-8 source chunks
        uint32      numCodeLocations;     // Number of chunks used (≤25)
        uint32[8]   p;                    // Series parameters
        uint256     numMint;              // Current minted count
        uint256     maxMint;              // Hard cap (512 for NotDeafbeef)
        bool        paused;               // Blocks minting if true
        bool        locked;               // Blocks code changes if true
        bool        publicMintEnabled;    // Allow free public minting
    }

    struct TokenParamsStruct {
        bytes32   seed;                   // 32-byte deterministic seed (immutable)
        uint32[8] p;                      // Token-specific parameters
    }

    // --- Storage ---
    mapping(uint256 => SeriesStruct) public series;
    uint256 public numSeries;

    mapping(uint256 => TokenParamsStruct) public tokenParams;
    mapping(uint256 => uint256) public token2series;

    uint256 private _nextTokenId = 1;
    string  private _baseTokenURI;

    // --- Events ---
    event SeriesAdded(uint256 indexed seriesId);
    event SeriesLocked(uint256 indexed seriesId);
    event SeriesPaused(uint256 indexed seriesId, bool paused);
    event SeriesMaxMintSet(uint256 indexed seriesId, uint256 maxMint);
    event SeriesPublicMintSet(uint256 indexed seriesId, bool enabled);
    event SeriesCodeLocationSet(uint256 indexed seriesId, uint32 indexed index, bytes32 txHash);
    event SeriesNumCodeLocationsSet(uint256 indexed seriesId, uint32 count);
    event NFTGenerated(address indexed to, uint256 indexed tokenId, uint256 indexed seriesId, bytes32 seed);

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MINTER_ROLE, _msgSender());
        
        // Initialize Series 0 for NotDeafbeef with 512 max supply
        uint256 s0 = _addSeries();
        series[s0].maxMint = 512;
        series[s0].publicMintEnabled = false; // Start disabled until code is set
    }

    // --- Modifiers ---
    modifier seriesExists(uint256 seriesId) {
        require(seriesId < numSeries, "Series: out of range");
        _;
    }

    modifier seriesUnlocked(uint256 seriesId) {
        require(!series[seriesId].locked, "Series: locked");
        _;
    }

    // --- Series Administration ---

    function addSeries() external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256) {
        return _addSeries();
    }

    function _addSeries() internal returns (uint256 seriesId) {
        seriesId = numSeries;
        SeriesStruct storage s = series[seriesId];
        s.paused = true;                   // Start paused
        s.locked = false;
        s.publicMintEnabled = false;       // Start disabled
        s.maxMint = 50;                    // Default (override as needed)
        s.numCodeLocations = 0;
        numSeries++;
        emit SeriesAdded(seriesId);
    }

    function lockCodeForever(uint256 seriesId)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        seriesExists(seriesId)
    {
        series[seriesId].locked = true;
        emit SeriesLocked(seriesId);
    }

    function setPaused(uint256 seriesId, bool paused_)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        seriesExists(seriesId)
    {
        series[seriesId].paused = paused_;
        emit SeriesPaused(seriesId, paused_);
    }

    function setMaxMint(uint256 seriesId, uint256 maxMint_)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        seriesExists(seriesId)
        seriesUnlocked(seriesId)
    {
        series[seriesId].maxMint = maxMint_;
        emit SeriesMaxMintSet(seriesId, maxMint_);
    }

    function setPublicMintEnabled(uint256 seriesId, bool enabled)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        seriesExists(seriesId)
    {
        series[seriesId].publicMintEnabled = enabled;
        emit SeriesPublicMintSet(seriesId, enabled);
    }

    function setNumCodeLocations(uint256 seriesId, uint32 count)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        seriesExists(seriesId)
        seriesUnlocked(seriesId)
    {
        require(count <= 25, "Max 25 code chunks");
        series[seriesId].numCodeLocations = count;
        emit SeriesNumCodeLocationsSet(seriesId, count);
    }

    function setCodeLocation(uint256 seriesId, uint32 index, bytes32 txHash)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        seriesExists(seriesId)
        seriesUnlocked(seriesId)
    {
        SeriesStruct storage s = series[seriesId];
        require(index < s.numCodeLocations, "Index out of bounds");
        s.codeLocations[index] = txHash;
        emit SeriesCodeLocationSet(seriesId, index, txHash);
    }

    function setSeriesParam(uint256 seriesId, uint32 i, uint32 value)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        seriesExists(seriesId)
        seriesUnlocked(seriesId)
    {
        require(i < 8, "Parameter index out of range");
        series[seriesId].p[i] = value;
    }

    function setTokenParam(uint256 tokenId, uint32 i, uint32 value)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_exists(tokenId), "Token does not exist");
        require(i < 8, "Parameter index out of range");
        tokenParams[tokenId].p[i] = value;
    }

    // --- Public Free Mint (Gas Only) ---

    /**
     * @notice Public, free mint (gas only). One token per call.
     *         Hard-capped at 512 total mints for Series 0.
     */
    function mintPublic(uint256 seriesId)
        external
        seriesExists(seriesId)
        returns (uint256 tokenId)
    {
        SeriesStruct storage s = series[seriesId];
        require(!s.paused, "Series is paused");
        require(s.publicMintEnabled, "Public mint disabled");
        require(s.numCodeLocations > 0, "Code not set");

        if (s.maxMint != 0) {
            require(s.numMint < s.maxMint, "Maximum mint reached");
        }

        tokenId = _mintInternal(_msgSender(), seriesId);
    }

    // --- Admin/Minter Functions ---

    function mint(address to, uint256 seriesId)
        external
        onlyRole(MINTER_ROLE)
        seriesExists(seriesId)
        returns (uint256 tokenId)
    {
        SeriesStruct storage s = series[seriesId];
        require(!s.paused, "Series is paused");
        require(s.numCodeLocations > 0, "Code not set");
        if (s.maxMint != 0) {
            require(s.numMint < s.maxMint, "Maximum mint reached");
        }
        tokenId = _mintInternal(to, seriesId);
    }

    function _mintInternal(address to, uint256 seriesId) internal returns (uint256 tokenId) {
        tokenId = _nextTokenId++;
        _safeMint(to, tokenId);

        // Generate pseudo-random seed for NFT uniqueness
        // Same as deafbeef: combines token ID + blockchain state
        bytes32 seed = keccak256(
            abi.encodePacked(
                tokenId,
                block.prevrandao,    // Randomness beacon (post-merge)
                block.timestamp,
                to
            )
        );

        tokenParams[tokenId].seed = seed;
        token2series[tokenId] = seriesId;

        series[seriesId].numMint += 1;
        emit NFTGenerated(to, tokenId, seriesId, seed);
    }

    // --- Reconstruction Interface (Public Getters) ---

    function getTokenParams(uint256 tokenId)
        external
        view
        returns (
            bytes32 seed,
            uint256 seriesId,
            uint32[8] memory tokenP,
            uint32[8] memory seriesP,
            uint32 numCodeLocations,
            bytes32 codeLocation0
        )
    {
        require(_exists(tokenId), "Token does not exist");
        seed = tokenParams[tokenId].seed;
        tokenP = tokenParams[tokenId].p;

        seriesId = token2series[tokenId];
        SeriesStruct storage s = series[seriesId];
        seriesP = s.p;
        numCodeLocations = s.numCodeLocations;
        codeLocation0 = (numCodeLocations > 0) ? s.codeLocations[0] : bytes32(0);
    }

    function getSeries(uint256 seriesId)
        external
        view
        seriesExists(seriesId)
        returns (
            uint32 numCodeLocations,
            bytes32[25] memory codeLocations,
            uint32[8] memory p,
            uint256 numMint,
            uint256 maxMint,
            bool paused,
            bool locked,
            bool publicMintEnabled
        )
    {
        SeriesStruct storage s = series[seriesId];
        numCodeLocations = s.numCodeLocations;
        codeLocations    = s.codeLocations;
        p                = s.p;
        numMint          = s.numMint;
        maxMint          = s.maxMint;
        paused           = s.paused;
        locked           = s.locked;
        publicMintEnabled = s.publicMintEnabled;
    }

    function getCodeLocation(uint256 seriesId, uint32 index)
        external
        view
        seriesExists(seriesId)
        returns (bytes32)
    {
        SeriesStruct storage s = series[seriesId];
        require(index < s.numCodeLocations, "Index out of bounds");
        return s.codeLocations[index];
    }

    function getSeed(uint256 tokenId) external view returns (bytes32) {
        require(_exists(tokenId), "Token does not exist");
        return tokenParams[tokenId].seed;
    }

    function tokenSeries(uint256 tokenId) external view returns (uint256) {
        require(_exists(tokenId), "Token does not exist");
        return token2series[tokenId];
    }

    // --- Optional: Transfer Counter (Deafbeef "Entropy" Style) ---
    // Uncomment to track transfers in p[7] for artistic degradation effects
    /*
    function _beforeTokenTransfer(
        address from, 
        address to, 
        uint256 tokenId, 
        uint256 batchSize
    ) internal override {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        
        // Increment transfer counter on each transfer (not mint/burn)
        if (from != address(0) && to != address(0)) {
            unchecked { 
                tokenParams[tokenId].p[7] += 1; 
            }
        }
    }
    */

    // --- Metadata (Optional) ---

    function setBaseURI(string calldata baseURI_) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        _baseTokenURI = baseURI_;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    // --- Interface Support ---

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
