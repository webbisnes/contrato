// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";


contract Lolo is ERC20, Ownable {
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    address public tokenReward;
    address public tokenBurn;
    address constant burnWallet = 0x000000000000000000000000000000000000dEaD;

    uint256 public constant MAX_SUPPLY = 1 * 10**15 * 10**18;

    // Impuesto de compra y venta
    uint256 public impuestoCompra = 6;
    uint256 public impuestoVenta = 10;

    mapping(address => bool) public excludedFromTax;
    mapping(address => bool) public excludedFromReward;
    mapping(address => bool) public excludedFromBurn;

    constructor(address _tokenReward, address _tokenBurn) ERC20("Lolo", "LOLO") {
        tokenReward = _tokenReward;
        tokenBurn = _tokenBurn;

        // Crear el par en Uniswap para la red de prueba
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());

        // Establecer el router de Uniswap para la red de prueba
        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

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

        if (recipient == uniswapV2Pair) {
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

            // Agregar liquidez a Uniswap
            uint256 tokenParaLiquidez = balanceOf(address(this));
            uint256 tokenParaETH = (tokenParaLiquidez * impuestoLiquidez) / 100;
            uint256 tokenParaToken = tokenParaLiquidez - tokenParaETH;

            if (tokenParaETH > 0) {
                // Aprobar el gasto de los tokens
                approve(address(uniswapV2Router), tokenParaETH);

                // Agregar liquidez a Uniswap
                uniswapV2Router.addLiquidityETH{value: tokenParaETH}(
                    address(this),
                    tokenParaToken,
                    0,
                    0,
                    owner(),
                    block.timestamp + 360
                );
            }
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
        (uint256 tokenAmount, uint256 ethAmount) = uniswapV2Router.removeLiquidityETH(
            address(this),
            balanceOf(uniswapV2Pair),
            0,
            0,
            owner(),
            block.timestamp
        );
        
        // Transferir los tokens y ETH a la dirección del propietario
        _transfer(address(this), owner(), tokenAmount);
        payable(owner()).transfer(ethAmount);
    }
}
