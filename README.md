# Crucible

## Description
Crucible is a cross-chain asset foundry that lets protocols bundle disparate tokens and NFTs into programmable "ingots" that can move between chains. It is built to smooth over three structural frictions that DeFi teams run into today:
- Liquidity is fragmented across many chains, leaving treasuries and treasurers unable to marshal depth in a single venue when they need it most.
- Cross-chain equivalents for tokens are poor substitutes for native assets, forcing maintainers to juggle bridge risk and liquidity incentives on every network.
- There is a lack of curated baskets of assets that can be forged, transported, and redeemed as one position without rebalancing legwork.

By letting maintainers author an `IngotSpec` once and reuse it everywhere, Crucible gives projects a way to create, distribute, and settle complex baskets with predictable mechanics.

## Key Features
- **Composable ingots:** Define baskets that can mix ERC-20, ERC-721, ERC-1155, and native tokens with deterministic ratios and transfer rules.
- **Cross-chain distribution:** Leverages LayerZero's OApp framework to mint and burn ingots across execution environments while keeping accounting consistent.
- **Fee-aware operations:** Wrap, unwrap, and bridge flows route through a pluggable fee calculator so that business logic can evolve without redeploying core contracts.

## Ingot Lifecycle Overview
1. **Invent** – Submit a validated specification and clone the base `Ingot` implementation to register a new basket within the Crucible registry.
2. **Forge** – Deposit the basket's underlying assets (or floor NFTs) and receive fungible ingot tokens representing ownership of the basket.
3. **Transmute** – Burn ingots on the origin chain, pay the LayerZero messaging fee, and recreate the position on a destination chain for the intended beneficiary.
4. **Dissolve** – Redeem ingots for the original assets, enforcing the same rules and ratios defined in the specification.

## Repository Layout
- `contracts/Crucible.sol` – Core orchestrator that manages ingot specs, lifecycle events, and cross-chain messaging.
- `contracts/Ingot.sol` – Minimal proxy implementation that wraps and unwraps assets according to the published spec.
- `contracts/interfaces/` – Canonical interfaces for ingots, fees, and crucible operations.
- `contracts/types/` – Struct definitions for `IngotSpec`, `NuggetSpec`, and related enums.
- `deploy/` – Hardhat deployment scripts and tags.
- `test/` – Foundry and Hardhat test suites (work in progress).

## Getting Started
### Prerequisites
- Node.js v18.16.0 or newer.
- npm (bundled with Node). pnpm is also supported through the overrides in `package.json` if you prefer a different client.
- [Foundry](https://book.getfoundry.sh/getting-started/installation) toolchain for Solidity testing.

### Installation
1. Install dependencies:
   ```bash
   npm install
   ```
2. Copy `.env.example` to `.env` (if present) and populate network-specific keys such as private keys, RPC URLs, and LayerZero endpoint addresses.

## Development Workflows
### Compile Contracts
```bash
npm run compile
```
This concurrently builds both the Foundry and Hardhat artifacts so you can use the toolkit that best fits your workflow.

### Run Tests
```bash
npm test
```
Runs the Foundry suite followed by Hardhat tests to validate contract behavior across toolchains.

### Lint & Format
```bash
npm run lint
```
Static analysis covers JavaScript/TypeScript utilities, Solidity contracts (via `solhint`), and formatting checks with Prettier.

## Deployment
Use Hardhat Deploy to target a configured network. For example, to deploy mocks on Optimism Sepolia:
```bash
npx hardhat deploy --network optimismSepolia --tags Mocks
```
Consult `layerzero.config.ts` for LayerZero endpoint configuration and `deploy/` for additional deployment tags.

## Contributing
Issues and pull requests are welcome. When proposing changes, please:
- Keep specifications and lifecycle invariants backwards compatible when possible.
- Add or update tests in both Hardhat and Foundry suites when the behavior changes.
- Run the lint and test commands shown above before opening a PR.

## License
The contracts are released under the terms specified in the SPDX headers of each file. Please review individual files for exact licensing details.
