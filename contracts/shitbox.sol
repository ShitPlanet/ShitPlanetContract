pragma solidity >=0.6.0;

import './utils/ERC721.sol';
import './utils/SafeMath.sol';
import './utils/IUniswapV2Router02.sol';
import './shit.sol';

interface IERC20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

contract ShitBox is ERC721 {
    using SafeMath for uint256;

    address usdtAddress = 0x0;
    address shitAddress = 0x0;
    address pancakeFactoryAddr = 0x0;
    address pancakeRouterAddr = 0x0;
    uint256 upgradePrice = 10000000000000000000; // 10 $SHIT

    Shit shit = Shit(shitAddress);
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
        
        uint256 boxId = _getNextBoxId();
        boxes[boxId] = Box(boxId, msg.sender, tokenAddress, amount, miningPower);
        _mint(msg.sender, boxId);
    }

    function upgradeShitBox(uint256 boxId) public {
        require(shit.transferFrom(msg.sender, address(0xdead), upgradePrice), "insufficient shit");
        require(boxes[boxId].shiter != 0x0);

        uint256 rand = _getRandom();
        uint256 currentMiningPower = boxes[boxId].miningPower;
        boxes[boxId].miningPower = currentMiningPower.add(rand);
    }
    
    // TODO: replace this with chainlink VRF
    function _getRandom() private view returns (uint256) {
        return 0;
    }

    function _magic(address tokenAddress, uint256 amount) private returns (uint256) {
        // transfer 50% to 0xdead
        uint256 burnAmount = amount.mul(50).div(100);
        require(token.transfer(address(0xdead), burnAmount), "Insufficient funds");
        // swap 50% to USDT
        address bridgeToken = shit.getBridgeToken(tokenAddress);
        address[] memory path;
        path.push(tokenAddress);
        if(bridgeToken != usdtAddress) {
            path.push(bridgeToken);
        }
        path.push(usdtAddress);
        IERC20 token = IERC20(tokenAddress);
        token.approve(pancakeRouterAddr, uint(-1));
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amount.sub(burnAmount), 0, path, address(this), block.timestamp + 500);
        uint256 usdtValue = usdt.balanceOf(address(this));
        // swap 25% to $SHIT
        address[] memory path1;
        path1.push(usdtAddress);
        path1.push(shitAddress);
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
        super._burn(_owner, _tokenId);
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
