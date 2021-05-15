// SPDX-License-Identifier: MIT

pragma solidity ^0.6.2;

import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/token/ERC721/ERC721.sol';
import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/math/SafeMath.sol';
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/token/ERC20/ERC20.sol";
import './IUniswapV2Router02.sol';
import './Shit.sol';
import "./vrf_on_bsc_testnet.sol";

contract ShitBox is ERC721 {
    using SafeMath for uint256;

    address usdtAddress = 0x55d398326f99059fF775485246999027B3197955;
    address shitAddress = 0x2Ee8908E893d3ebEA14c87A5d85f78850c6192FA;
    address pancakeRouterAddr = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address vrfAddr = address(0x0); 
    uint256 upgradePrice = 100000000000000000000; // 100 $SHIT
    uint256 burnedCounter = 0;

    Shit shit = Shit(shitAddress);
    ERC20 usdt = ERC20(usdtAddress);
    IUniswapV2Router02 router = IUniswapV2Router02(pancakeRouterAddr);
    
    struct Box {
        uint256 id;
        address shiter;
        address tokenAddress;
        uint256 amount;
        uint256 initUSDValue;
        uint256 quality; 

        uint256 bonusPower;
        uint256 miningPower;
    }
    mapping(uint256 => Box) boxes;

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) public {
        shit.approve(pancakeRouterAddr, uint(-1));
        usdt.approve(pancakeRouterAddr, uint(-1));
    }

    function getMiningPower(uint256 boxId) public view returns (uint256) {
        return boxes[boxId].miningPower;
    }
    
    function mintShitBox(address tokenAddress, uint256 amount) public {
        require(shit.isShitToken(tokenAddress));

        ERC20 token = ERC20(tokenAddress);
        require(token.transferFrom(msg.sender, address(this), amount), "Insufficient funds");
        
        // burn 50%, swap 25% to $SHIT, 25% to USDT, add liquidity for $SHIT
        uint256 miningPower = _magic(tokenAddress, amount);
        // VRF 
        uint256 rand = _getRand();
        rand = rand.mod(100);
        uint256 quality = 0;
        
        if (rand > 95) quality = 5;
        else if (rand > 85) quality = 4;
        else if (rand > 65) quality = 3;
        else if (rand > 35) quality = 2;
        else quality = 1;

        uint256 boxId = _getNextBoxId();
        boxes[boxId] = Box(boxId, msg.sender, tokenAddress, amount, miningPower, quality, 0, miningPower.mul(quality));
        _mint(msg.sender, boxId);
    }

    function upgradeShitBox(uint256 boxId) public {
        require(msg.sender == tx.origin); // ban contract call
        require(shit.transferFrom(msg.sender, address(0xdead), upgradePrice), "insufficient shit");
        require(boxes[boxId].shiter != address(0x0));
        
        // Link VRF Supported next version
        
        uint256 rand = uint256(blockhash(block.number-1)).mod(1000);
        
        uint256 bonus = 0;

        if (rand > 998) bonus = 100000;
        else if (rand > 979) bonus = 10000;
        else if (rand > 800) bonus = 1000;
        else bonus = 100;

        uint256 currentMiningPower = boxes[boxId].miningPower;
        uint256 currentBonusPower = boxes[boxId].bonusPower;
        boxes[boxId].miningPower = currentMiningPower.add(bonus.mul(10**18));
        boxes[boxId].bonusPower = currentBonusPower.add(bonus.mul(10**18));
    }

    function _getRand() private returns (uint) {
        // return _getRandom(block.timestamp, vrfAddr);
        return uint(blockhash(block.number - 1));
    }
    
    // TODO: replace this with chainlink VRF
    function _getRandom(uint256 userProvidedSeed, address vrfContractAddress) private returns (uint256) {
        RandomNumberConsumer randomNumberConsumer = RandomNumberConsumer(vrfContractAddress);
        uint256 randomResult = uint256(randomNumberConsumer.getRandomNumber(userProvidedSeed));
        return randomResult;
    }

    function _magic(address tokenAddress, uint256 amount) private returns (uint256) {
        // transfer 50% to 0xdead
        ERC20 token = ERC20(tokenAddress);
        uint256 burnAmount = amount.mul(50).div(100);
        require(token.transfer(address(0xdead), burnAmount), "Insufficient funds");
        // swap 50% to USDT
        address bridgeToken = shit.getBridgeToken(tokenAddress);
        address[] memory path00 = new address[](2);
        address[] memory path01 = new address[](3);
        path00[0] = tokenAddress;
        path00[1] = usdtAddress;
        
        path01[0] = tokenAddress;
        path01[1] = bridgeToken;
        path01[2] = usdtAddress;
       
        token.approve(pancakeRouterAddr, uint(-1));
        if(bridgeToken == usdtAddress) {
            router.swapExactTokensForTokens(amount.sub(burnAmount), 0, path00, address(this), block.timestamp + 500);
        } else {
            router.swapExactTokensForTokens(amount.sub(burnAmount), 0, path01, address(this), block.timestamp + 500);
        }
        uint256 usdtValue = usdt.balanceOf(address(this));
        // swap 25% to $SHIT
        address[] memory path1 = new address[](2);
        path1[0] = usdtAddress;
        path1[1] = shitAddress;
        router.swapExactTokensForTokens(usdtValue.mul(50).div(100), 0, path1, address(this), block.timestamp + 500);
        uint256 usdtBalance = usdt.balanceOf(address(this));
        uint256 shitBalance = shit.balanceOf(address(this));
        // add liquidity for SHIT/USDT
        router.addLiquidity(usdtAddress, shitAddress, usdtBalance, shitBalance, 0, 0, address(0xdead), block.timestamp + 500);
        
        return usdtValue;
    }

    function skim(address tokenAddress) public {
        ERC20 token = ERC20(tokenAddress);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function _getNextBoxId() private view returns (uint256) {
        return totalSupply().add(1).add(burnedCounter);
    }

    function _burn(address _owner, uint256 _tokenId) internal {
        super._burn(_tokenId);
        burnedCounter++;
    }

    function tokensOfOwner(address _owner) external view returns(uint256[] memory ownerTokens) {
        uint256 tokenCount = balanceOf(_owner);

        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 resultIndex = 0;
            uint256 _tokenIdx;
            for (_tokenIdx = 0; _tokenIdx < tokenCount; _tokenIdx++) {
                result[resultIndex] = tokenOfOwnerByIndex(_owner, _tokenIdx);
                resultIndex++;
            }
            return result;
        }
    }
}
