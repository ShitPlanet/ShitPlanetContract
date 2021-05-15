// SPDX-License-Identifier: MIT

pragma solidity ^0.6.2;

import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/token/ERC721/ERC721.sol';
import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/math/SafeMath.sol';
import './IUniswapV2Router02.sol';
import './Shit.sol';
import "./vrf_on_bsc_testnet.sol";

contract ShitBox is ERC721 {
    using SafeMath for uint256;

    address usdtAddress = address(0x0);
    address shitAddress = address(0x0);
    address pancakeFactoryAddr = address(0x0);
    address pancakeRouterAddr = address(0x0);
    address vrfAddr = address(0x0);
    uint256 upgradePrice = 100000000000000000000; // 100 $SHIT
    uint256 burnedCounter = 0;

    Shit shit = Shit(shitAddress);
    IERC20 usdt = IERC20(usdtAddress);
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
        
        if (rand > 95) quality = miningPower.mul(5);
        else if (rand > 85) quality = miningPower.mul(4);
        else if (rand > 65) quality = miningPower.mul(3);
        else if (rand > 35) quality = miningPower.mul(2);
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
        boxes[boxId].miningPower = currentMiningPower.add(bonus);
        boxes[boxId].bonusPower = currentBonusPower.add(bonus);
    }

    function _getRand() private returns (uint) {
        return _getRandom(block.timestamp, vrfAddr);
    }
    
    // TODO: replace this with chainlink VRF
    function _getRandom(uint256 userProvidedSeed, address vrfContractAddress) private returns (uint256) {
        RandomNumberConsumer randomNumberConsumer = RandomNumberConsumer(vrfContractAddress);
        uint256 randomResult = uint256(randomNumberConsumer.getRandomNumber(userProvidedSeed));
        return randomResult;
    }

    function _magic(address tokenAddress, uint256 amount) private returns (uint256) {
        // transfer 50% to 0xdead
        IERC20 token = IERC20(tokenAddress);
        uint256 burnAmount = amount.mul(50).div(100);
        require(token.transfer(address(0xdead), burnAmount), "Insufficient funds");
        // swap 50% to USDT
        address bridgeToken = shit.getBridgeToken(tokenAddress);
        address[] memory path = new address[](3);
        path[0] = tokenAddress;
        if(bridgeToken != usdtAddress) {
            path[1] = bridgeToken;
        }
        if(path[1] != address(0x0)){
            path[2] = usdtAddress;   
        }else{
            path[1] = usdtAddress;
        }
        token.approve(pancakeRouterAddr, uint(-1));
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amount.sub(burnAmount), 0, path, address(this), block.timestamp + 500);
        uint256 usdtValue = usdt.balanceOf(address(this));
        // swap 25% to $SHIT
        address[] memory path1 = new address[](2);
        path1[0] = usdtAddress;
        path1[1] = shitAddress;
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(usdtValue.mul(50).div(100), 0, path1, address(this), block.timestamp + 500);
        uint256 usdtBalance = usdt.balanceOf(address(this));
        uint256 shitBalance = shit.balanceOf(address(this));
        // add liquidity for SHIT/USDT
        router.addLiquidity(tokenAddress, usdtAddress, usdtBalance, shitBalance, 0, 0, address(0xdead), block.timestamp + 500);

        return usdtValue;
    }

    function skim(address tokenAddress) public {
        IERC20 token = IERC20(tokenAddress);
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
