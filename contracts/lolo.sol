// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3Pool.sol";

contract CustomToken is ERC20, Ownable {
    ISwapRouter public swapRouter;
    IUniswapV3Pool public uniswapV3Pool;

    address public tokenReward;
    address public tokenBurn;
    address public burnWallet = 0x000000000000000000000000000000000000dEaD;

    uint256 public constant MAX_SUPPLY = 1 * 10**15 * 10**18;

    // Impuesto de compra y venta
    uint256 public impuestoCompra = 6;
    uint256 public impuestoVenta = 10;

    mapping(address => bool) public excludedFromTax;
    mapping(address => bool) public excludedFromReward;
    mapping(address => bool) public excludedFromBurn;

    constructor(address _tokenReward, address _tokenBurn) ERC20("CustomToken", "CTK") {
        tokenReward = _tokenReward;
        tokenBurn = _tokenBurn;

        // Crear el par en Uniswap
        //Mainnet - 0xE592427A0AEce92De3Edee1F18E0157C05861564
        //TESNET GOERLI - 0x13B2077A039Aa0d0eCcBf6c68ACD46B60B4B4b4A
        
        swapRouter = ISwapRouter(0x13B2077A039Aa0d0eCcBf6c68ACD46B60B4B4b4A);
        uniswapV3Pool = IUniswapV3Pool(swapRouter.exactOutputSingle(
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(this),
                tokenOut: swapRouter.WETH9(),
                fee: 3000, // 0.3% fee
                recipient: address(this),
                deadline: block.timestamp + 1800, // 30 minutes from now
                amountOut: 1, // We only care about the WETH price of this token
                amountInMaximum: MAX_SUPPLY, // We want to swap all tokens in the pool
                sqrtPriceLimitX96: 0
            })
        ).pool);

        // Mint tokens al propietario
        _mint(owner(), MAX_SUPPLY);

        // Excluir al contrato y propietario de impuestos y recompensas
        excludedFromTax[address(this)] = true;
        excludedFromTax[owner()] = true;
        excludedFromReward[address(this)] = true;
        excludedFromReward[owner()] = true;
        excludedFromBurn[address(this)] = true;
        excludedFromBurn[owner()] = true;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(amount > 0, "Debe transferir al menos un token");

        uint256 impuesto = impuestoCompra;
        uint256 montoTransferencia = amount - (amount * impuesto) / 100;

        if (recipient == address(uniswapV3Pool)) {
            impuesto = impuestoVenta;
            montoTransferencia = amount - (amount * impuesto) / 100;
        }

        if (!excludedFromTax[_msgSender()]) {
            super.transfer(recipient, montoTransferencia);
        } else {
            super.transfer(recipient, amount);
        }

        // Distribución de impuestos
       
   if (!excludedFromTax[_msgSender()]) {
        uint256 impuestoBurn = (amount * impuesto) / 100;
        uint256 impuestoReward = (amount * impuesto) / 100;
        uint256 impuestoLiquidez = (amount * impuesto) / 100;
        uint256 impuestoMarketing = (amount * impuesto) / 100;

        super.transfer(burnWallet, impuestoBurn);
        super.transfer(tokenReward, impuestoReward);
        super.transfer(address(this), impuestoLiquidez);
        super.transfer(owner(), impuestoMarketing);
    }

    return true;
}

function setExcludedFromTax(address account, bool excluded) external onlyOwner {
    excludedFromTax[account] = excluded;
}

function setExcludedFromReward(address account, bool excluded) external onlyOwner {
    excludedFromReward[account] = excluded;
}

function setExcludedFromBurn(address account, bool excluded) external onlyOwner {
    excludedFromBurn[account] = excluded;
}

function setImpuestoCompra(uint256 newImpuesto) external onlyOwner {
    impuestoCompra = newImpuesto;
}

function setImpuestoVenta(uint256 newImpuesto) external onlyOwner {
    impuestoVenta = newImpuesto;
}

function setTokenReward(address newTokenReward) external onlyOwner {
    tokenReward = newTokenReward;
}

function setTokenBurn(address newTokenBurn) external onlyOwner {
    tokenBurn = newTokenBurn;
}

function withdrawLiquidity() external onlyOwner {
    // Obtener la cantidad de tokens y ETH en la liquidez
    (uint256 tokenAmount, uint256 ethAmount) = uniswapV3Pool.burn(
        address(this)
    );

    // Transferir los tokens y ETH a la dirección del propietario
    _transfer(address(this), owner(), tokenAmount);
    payable(owner()).transfer(ethAmount);
}
}
