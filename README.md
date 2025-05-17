# Ticketerium - Decentralized Event Ticket System DApp

Welcome to Ticketerium, a decentralized application (DApp) built on the Ethereum blockchain using the Sepolia Testnet. This project provides a secure and transparent platform for event ticketing, leveraging MetaMask for wallet integration and smart contracts for ticket management.

## Features

- **Secure Login**: Connect via MetaMask wallet for authenticated access.
- **Event Management**: Create, browse, and manage events with customizable details (name, description, location, date, price, etc.).
- **Ticket Operations**: Buy, verify, transfer, and refund tickets directly on the blockchain.
- **Organizer Controls**: Cancel events, withdraw funds, and pause/unpause the contract.
- **User Dashboard**: Intuitive interface to view and manage tickets and events.
- **Decentralized**: Powered by Ethereum smart contracts for trustless transactions.

## Installation and Setup

### Prerequisites
- [Node.js](https://nodejs.org/) (v14 or later)
- [MetaMask](https://metamask.io/) browser extension configured for Sepolia Testnet
- Sepolia ETH (obtain from https://sepoliafaucet.com/)
- A modern web browser (Chrome, Firefox recommended)

### Steps
1. **Clone the Repository**
   ```bash
   git clone https://github.com/yourusername/ticketerium.git
   cd ticketerium
   ```

2. **Install Dependencies**
   - Ensure `http-server` is installed globally:
     ```bash
     npm install -g http-server
     ```

3. **Configure MetaMask**
   - Switch to Sepolia Testnet in MetaMask.
   - Fund your wallet with test ETH from the faucet.

4. **Run the Application**
   - Start the local server:
     ```bash
     http-server
     ```
   - Open your browser and navigate to `http://localhost:8080/index.html`.

## Usage

1. **Login**
   - Visit `index.html` and click "Connect Wallet" to link your MetaMask account.
   - Upon successful connection, you’ll be redirected to `dashboard.html`.

2. **Dashboard**
   - **Browse Events**: View available events.
   - **Create Event**: Fill out the form to create a new event.
   - **Organizer Controls**: Manage events (cancel, withdraw, pause/unpause).
   - **Ticket Actions**: Verify, transfer, or refund tickets using event and ticket IDs.
   - **My Tickets**: Check your purchased tickets.

3. **Testing**
   - Use developer tools (F12) to monitor console logs for wallet connection details.
   - Ensure MetaMask prompts are visible for transactions.

## Technologies Used

- **Frontend**: HTML, CSS (Bootstrap 5.3.0), JavaScript
- **Blockchain**: Web3.js 1.7.3, Ethereum Sepolia Testnet
- **Fonts**: Google Fonts (Roboto)
- **Icons**: Bootstrap Icons 1.10.5
- **Styling**: Custom CSS with Strapi-inspired color scheme

## Contributing

Contributions are welcome! Please fork the repository and submit pull requests. For major changes, please open an issue first to discuss.

1. Fork the repo.
2. Create a new branch (`git checkout -b feature-branch`).
3. Commit your changes (`git commit -m 'Add new feature'`).
4. Push to the branch (`git push origin feature-branch`).
5. Open a pull request.

## License

This project is licensed under the [MIT License](LICENSE). Feel free to use, modify, and distribute it.

## Contact and Support

- **GitHub**: [yourusername/ticketerium](https://github.com/yourusername/ticketerium)
- **Issues**: Report bugs or request features on the [Issues page](https://github.com/yourusername/ticketerium/issues).
- **Email**: [your-email@example.com](mailto:your-email@example.com)

## Screenshots

- Add screenshots of the login page and dashboard here (e.g., `![Login Page](screenshots/login.png)`).
- Example: Upload images to the `screenshots` folder and reference them.

## Acknowledgments

- Inspired by Strapi’s design aesthetics.
- Thanks to the Ethereum and Sepolia Testnet communities for blockchain support.
- Gratitude to Bootstrap and Google Fonts for open-source resources.