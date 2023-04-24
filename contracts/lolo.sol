// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract CustomToken is ERC20, Ownable {
    INonfungiblePositionManager public immutable nonfungiblePositionManager;
    ISwapRouter public immutable swapRouter;

    uint256 public constant MAX_SUPPLY = 1 * 10**15 * 10**18;

    // Impuesto de compra y venta
    uint256 public impuestoCompra = 6;
    uint256 public impuestoVenta = 10;

    mapping(address => bool) public excludedFromTax;
    mapping(address => bool) public excludedFromReward;
    mapping(address => bool) public excludedFromBurn;

    constructor(address _nonfungiblePositionManager, address _swapRouter) ERC20("CustomToken", "CTK") {
        nonfungiblePositionManager = INonfungiblePositionManager(_nonfungiblePositionManager);
        swapRouter = ISwapRouter(_swapRouter);

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

        if (recipient == address(nonfungiblePositionManager)) {
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

            super.transfer(address(nonfungiblePositionManager), impuestoLiquidez);
            super.transfer(owner(), impuestoMarketing);

            // Realizar el swap para obtener tokens de recompensa y quemar tokens
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = address(0);

            uint256 deadline = block.timestamp + 300; // 5 minutos
            uint256 amountOutMin = 0;

            // Realizar el swap para obtener tokens de recompensa y quemar tokens
            swapRouter.exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: address(this),
                    tokenOut: address(0),
                    fee: 3000,
                    recipient: address(this),
                    deadline: deadline,
                    amountIn: impuestoBurn,
                    amountOutMinimum: amountOutMin,
                    sqrtPriceLimitX96: 0
                })
            );
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

    function withdrawLiquidity() external onlyOwner {
        // Obtener la posición de liquidez más reciente del contrato
        uint256 tokenId = nonfungiblePositionManager.balanceOf(address(this)) - 1;
        (uint256 amount0, uint256 amount1) = nonfungiblePositionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        // Realizar el swap de los tokens de Uniswap por ETH
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = swapRouter.WETH9();

        uint256 amountIn = (amount0 > 0) ? amount0 : amount1;
        uint256 deadline = block.timestamp + 300; // 5 minutos

        ERC20(address(this)).approve(address(swapRouter), amountIn);
        swapRouter.swapExactTokensForETH(amountIn, 0, path, address(this), deadline);

        // Transferir ETH al propietario
        payable(owner()).transfer(address(this).balance);
    }
}
