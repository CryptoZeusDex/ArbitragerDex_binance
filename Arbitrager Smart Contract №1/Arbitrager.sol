// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface BEP20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function totalSupply() external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface ERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function totalSupply() external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract DexPrice {
    address public tokenA;
    address public tokenB;
    address public dex1;
    address public dex2;
    address public dex3;
    uint256 public priceAB;
    uint256 public priceBC;
    uint256 public priceCA;
    uint256 public fee1; // fee of dex1
    uint256 public fee2; // fee of dex2
    uint256 public fee3; // fee of dex3
    uint256 public gasPrice; // gas price for the transaction
    
    constructor(address _tokenA, address _tokenB, address _dex1, address _dex2, address _dex3) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        dex1 = _dex1;
        dex2 = _dex2;
        dex3 = _dex3;
    }
    
    function updatePrices() external {
        uint256 balanceA1 = BEP20(tokenA).balanceOf(dex1);
        uint256 balanceA2 = BEP20(tokenA).balanceOf(dex2);
        uint256 balanceA3 = BEP20(tokenA).balanceOf(dex3);
        uint256 balanceB1 = BEP20(tokenB).balanceOf(dex1);
        uint256 balanceB2 = BEP20(tokenB).balanceOf(dex2);
        uint256 balanceB3 = BEP20(tokenB).balanceOf(dex3);
        uint256 totalSupply1 = BEP20(dex1).totalSupply();
        uint256 totalSupply2 = BEP20(dex2).totalSupply();
        uint256 totalSupply3 = BEP20(dex3).totalSupply();
        fee1 = (totalSupply1 > 0) ? ((balanceA1 * 1e18) / totalSupply1) / 100 : 0;
        fee2 = (totalSupply2 > 0) ? ((balanceB2 * 1e18) / totalSupply2) / 100 : 0;
        fee3 = (totalSupply3 > 0) ? ((balanceB3 * 1e18) / totalSupply3) / 100 : 0;
        priceAB = (balanceA1 * 1e18) / balanceB1;
        priceBC = (balanceB2 * 1e18) / balanceA2;
        priceCA = (balanceA3 * 1e18) / balanceB3;
    }
function getPriceAB() external view returns (uint256) {
    return priceAB;
}

function getPriceBC() external view returns (uint256) {
    return priceBC;
}

function getPriceCA() external view returns (uint256) {
    return priceCA;
}

function checkArbitrage() external view returns (bool) {
    uint256 balanceWBNB = BEP20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c).balanceOf(address(this));
    uint256 tokenAAmount = (balanceWBNB * priceAB) / 1e18;
    uint256 tokenBAmount = (tokenAAmount * priceBC) / 1e18;
    uint256 wbnbAmount = (tokenBAmount * priceCA) / 1e18;
    uint256 gasCost = gasPrice * 21000;
    uint256 profit = wbnbAmount - gasCost;
    return (profit > 0);
}


function getDifference() external view returns (uint256) {
    uint256 diffABBC = (priceAB > priceBC) ? priceAB - priceBC : priceBC - priceAB;
    uint256 diffBCAC = (priceBC > priceCA) ? priceBC - priceCA : priceCA - priceBC;
    uint256 diffACAB = (priceCA > priceAB) ? priceCA - priceAB : priceAB - priceCA;
    uint256 totalFee = (diffABBC * fee1) / 1e18 + (diffBCAC * fee2) / 1e18 + (diffACAB * fee3) / 1e18;
    return (diffABBC + diffBCAC + diffACAB - totalFee) / 3;
}


function arbitrage(uint256 amount) external {
    uint256 balanceWBNB = BEP20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c).balanceOf(address(this));
    require(balanceWBNB >= amount, "Insufficient WBNB balance");
    
    // Calculate how much tokens we can get by swapping WBNB to TokenA on DEX1
    uint256 tokenAAmount = (amount * priceAB) / 1e18;
    
    // Calculate how much tokens we can get by swapping TokenA to TokenB on DEX2
    uint256 tokenBAmount = (tokenAAmount * priceBC) / 1e18;
    
    // Calculate how much tokens we can get by swapping TokenB to WBNB on DEX3
    uint256 wbnbAmount = (tokenBAmount * priceCA) / 1e18;
    
    // Make the swaps and profit
    uint256 gasCost = gasPrice * 21000; // assume gas limit of 21000
    BEP20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c).transferFrom(msg.sender, address(this), amount);
    BEP20(tokenA).approve(dex1, tokenAAmount);
    BEP20(tokenA).transferFrom(dex1, address(this), tokenAAmount);
    BEP20(tokenB).approve(dex2, tokenBAmount);
    BEP20(tokenB).transferFrom(dex2, address(this), tokenBAmount);
    BEP20(tokenB).approve(dex3, tokenBAmount);
    BEP20(tokenB).transferFrom(dex3, address(this), tokenBAmount);
    uint256 profit = wbnbAmount - gasCost;
    BEP20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c).transfer(msg.sender, profit);
}

function transferToken(address token, address recipient, uint256 amount) external {
    require(token == tokenA || token == tokenB, "Invalid token");
    require(msg.sender == owner(), "Only contract owner can transfer tokens");
    require(BEP20(token).transfer(recipient, amount), "Transfer failed");
}
function approveToken(address token, address spender, uint256 amount) external {
    require(token == tokenA || token == tokenB, "Invalid token");
    require(msg.sender == owner(), "Only contract owner can approve tokens");
    require(BEP20(token).approve(spender, amount), "Approval failed");
}

function transferFromToken(address token, address sender, address recipient, uint256 amount) external {
    require(token == tokenA || token == tokenB, "Invalid token");
    require(msg.sender == owner(), "Only contract owner can transfer tokens");
    require(BEP20(token).transferFrom(sender, recipient, amount), "Transfer failed");
}

function owner() internal view returns (address) {
    return msg.sender;
}

function setGasPrice(uint256 _gasPrice) external {
    require(msg.sender == owner(), "Only contract owner can set gas price");
    gasPrice = _gasPrice;
}

function getFee1() external view returns (uint256) {
    return fee1;
}

function getFee2() external view returns (uint256) {
    return fee2;
}

function getFee3() external view returns (uint256) {
    return fee3;
}

function getGasPrice() external view returns (uint256) {
    return gasPrice;
}
}
