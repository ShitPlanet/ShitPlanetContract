// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Goverance.sol";
import "./utils/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./vrf_on_bsc_testnet.sol";

contract ShitNFT is ERC721{
    
    using SafeMath for uint256;
    
    address usdtAddress = address(0x0);
    address shitAddress = address(0x0);
    address pancakeFactoryAddr = address(0x0);
    address pancakeRouterAddr = address(0x0);
    uint256 upgradePrice = 10000000000000000000; // 10 $SHIT
    uint256 burnedCounter = 0;
    mapping(address => uint256[]) tokens;

    ShitToken shit = ShitToken(shitAddress);
    IERC20 usdt = IERC20(usdtAddress);
    IUniswapV2Router02 router = IUniswapV2Router02(pancakeRouterAddr);
    
    struct Box {
        uint256 id;
        address shiter;
        address tokenAddress;
        uint256 amount;
        
        uint256 miningPower;
    }
    mapping(uint256 => Box) boxes;

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        // TODO uint(-1)
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
        
        uint256 boxId = _getNextBoxId();
        boxes[boxId] = Box(boxId, msg.sender, tokenAddress, amount, miningPower);
        _mint(msg.sender, boxId);
        tokens[msg.sender].push(boxId);
    }

    function upgradeShitBox(uint256 boxId) public {
        require(shit.transferFrom(msg.sender, address(0xdead), upgradePrice), "insufficient shit");
        require(boxes[boxId].shiter != address(0x0));

        uint256 rand = _getRandom();
        uint256 currentMiningPower = boxes[boxId].miningPower;
        boxes[boxId].miningPower = currentMiningPower.add(rand);
    }
    
      // TODO: replace this with chainlink VRF
    function _getRandom(uint256 userProvidedSeed, address vrfContractAddress) private view returns (uint256) {
        RandomNumberConsumer randomNumberConsumer = RandomNumberConsumer(vrfContractAddress);
        uint256 randomResult = randomNumberConsumer.getRandomNumber(userProvidedSeed);
        return randomResult;
    }

    function _magic(address tokenAddress, uint256 amount) private returns (uint256) {
        // transfer 50% to 0xdead
        IERC20 token = IERC20(tokenAddress);
        uint256 burnAmount = amount.mul(50).div(100);
        require(token.transfer(address(0xdead), burnAmount), "Insufficient funds");
        // swap 50% to USDT
        address bridgeToken = shit.getBridgeToken(tokenAddress);
        address[] memory path = new address[](2);
        path[0] = tokenAddress;
        if(bridgeToken != usdtAddress) {
            path[1] = bridgeToken;
        }else{
            path[1] = usdtAddress;
        }
        // TODO uint(-1)
        token.approve(pancakeRouterAddr, uint(1));
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
        return shit.totalSupply().add(1).add(burnedCounter);
    }

    function _burn(address _owner, uint256 _tokenId) internal {
        super._burn(_tokenId);
        burnedCounter++;
    }

    function tokensOfOwner(address _owner) external view returns(uint256[] memory ownerTokens) {
        // uint256 tokenCount = balanceOf(_owner);
        return tokens[_owner];
        // if (tokenCount == 0) {
        //     return new uint256[](0);
        // } else {
        //     uint256[] memory result = new uint256[](tokenCount);
        //     uint256 resultIndex = 0;
        //     uint256 _tokenIdx;
        //     for (_tokenIdx = 0; _tokenIdx < tokenCount; _tokenIdx++) {
        //         result[resultIndex] = tokenOfOwnerByIndex(_owner, _tokenIdx);
        //         resultIndex++;
        //     }
        //     return result;
        // }
    }
    
}