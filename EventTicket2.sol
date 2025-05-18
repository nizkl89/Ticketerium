// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EventTicketing {
    address public owner;
    bool public paused;

    struct Event {
        string name;
        string description;
        string location;
        uint256 date;
        uint256 ticketPrice;
        uint256 totalSupply;
        uint256 ticketsSold;
        uint256 resalePriceCap;
        bool transferable;
        bool canceled;
        bool exists;
    }

    mapping(uint256 => Event) public events;
    mapping(uint256 => mapping(uint256 => address)) public ticketOwners;
    mapping(uint256 => mapping(address => uint256[])) public userTickets;
    uint256 public eventCounter;

    event EventCreated(uint256 indexed eventId, string name, uint256 date);
    event TicketPurchased(
        uint256 indexed eventId,
        uint256 ticketId,
        address buyer
    );
    event TicketTransferred(
        uint256 indexed eventId,
        uint256 ticketId,
        address from,
        address to
    );
    event EventCanceled(uint256 indexed eventId);
    event RefundIssued(
        uint256 indexed eventId,
        uint256 ticketId,
        address to,
        uint256 amount
    );
    event FundsWithdrawn(address to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier nonReentrant() {
        bool _entered;
        require(!_entered, "Reentrant call");
        _entered = true;
        _;
        _entered = false;
    }

    constructor() {
        owner = msg.sender;
        eventCounter = 0;
    }

    /// @notice Creates a new event with specified details
    /// @param _name The name of the event
    /// @param _description A description of the event
    /// @param _location The location of the event
    /// @param _date The timestamp of the event
    /// @param _ticketPrice The price per ticket in wei
    /// @param _totalSupply The total number of tickets available
    /// @param _resalePriceCap The maximum resale price for tickets
    /// @param _transferable Whether tickets can be transferred
    function createEvent(
        string memory _name,
        string memory _description,
        string memory _location,
        uint256 _date,
        uint256 _ticketPrice,
        uint256 _totalSupply,
        uint256 _resalePriceCap,
        bool _transferable
    ) external onlyOwner whenNotPaused {
        require(bytes(_name).length > 0, "Event name cannot be empty");
        require(
            _date > block.timestamp + 1 hours,
            "Event date must be at least 1 hour in future"
        );
        require(_totalSupply > 0, "Total supply must be greater than 0");
        require(_totalSupply <= 10000, "Total supply exceeds maximum limit");
        require(
            _resalePriceCap >= _ticketPrice,
            "Resale price cap must be at least ticket price"
        );

        eventCounter++;
        events[eventCounter] = Event({
            name: _name,
            description: _description,
            location: _location,
            date: _date,
            ticketPrice: _ticketPrice,
            totalSupply: _totalSupply,
            ticketsSold: 0,
            resalePriceCap: _resalePriceCap,
            transferable: _transferable,
            canceled: false,
            exists: true
        });

        emit EventCreated(eventCounter, _name, _date);
    }

    /// @notice Purchases a single ticket for an event
    /// @param _eventId The ID of the event
    function purchaseTicket(
        uint256 _eventId
    ) external payable whenNotPaused nonReentrant {
        Event storage evt = events[_eventId];
        require(evt.exists, "Event does not exist");
        require(!evt.canceled, "Event is canceled");
        require(evt.ticketsSold < evt.totalSupply, "No tickets available");
        require(msg.value >= evt.ticketPrice, "Insufficient payment");

        evt.ticketsSold++;
        ticketOwners[_eventId][evt.ticketsSold] = msg.sender;
        userTickets[_eventId][msg.sender].push(evt.ticketsSold);

        emit TicketPurchased(_eventId, evt.ticketsSold, msg.sender);

        if (msg.value > evt.ticketPrice) {
            payable(msg.sender).transfer(msg.value - evt.ticketPrice);
        }
    }

    /// @notice Purchases multiple tickets for an event
    /// @param _eventId The ID of the event
    /// @param _quantity The number of tickets to purchase
    function purchaseTickets(
        uint256 _eventId,
        uint256 _quantity
    ) external payable whenNotPaused nonReentrant {
        Event storage evt = events[_eventId];
        require(evt.exists, "Event does not exist");
        require(!evt.canceled, "Event is canceled");
        require(
            evt.ticketsSold + _quantity <= evt.totalSupply,
            "Not enough tickets available"
        );
        require(
            msg.value >= evt.ticketPrice * _quantity,
            "Insufficient payment"
        );
        require(_quantity > 0, "Quantity must be greater than 0");

        uint256 startId = evt.ticketsSold + 1;
        evt.ticketsSold += _quantity;
        for (uint256 i = 0; i < _quantity; i++) {
            ticketOwners[_eventId][startId + i] = msg.sender;
            userTickets[_eventId][msg.sender].push(startId + i);
            emit TicketPurchased(_eventId, startId + i, msg.sender);
        }

        if (msg.value > evt.ticketPrice * _quantity) {
            payable(msg.sender).transfer(
                msg.value - evt.ticketPrice * _quantity
            );
        }
    }

    /// @notice Transfers a ticket to another address
    /// @param _eventId The ID of the event
    /// @param _ticketId The ID of the ticket
    /// @param _to The address to transfer the ticket to
    function transferTicket(
        uint256 _eventId,
        uint256 _ticketId,
        address _to
    ) external whenNotPaused {
        require(events[_eventId].exists, "Event does not exist");
        require(events[_eventId].transferable, "Tickets are not transferable");
        require(
            ticketOwners[_eventId][_ticketId] == msg.sender,
            "Not ticket owner"
        );
        require(_to != address(0), "Cannot transfer to zero address");

        ticketOwners[_eventId][_ticketId] = _to;
        for (uint256 i = 0; i < userTickets[_eventId][msg.sender].length; i++) {
            if (userTickets[_eventId][msg.sender][i] == _ticketId) {
                userTickets[_eventId][msg.sender][i] = userTickets[_eventId][
                    msg.sender
                ][userTickets[_eventId][msg.sender].length - 1];
                userTickets[_eventId][msg.sender].pop();
                break;
            }
        }
        userTickets[_eventId][_to].push(_ticketId);

        emit TicketTransferred(_eventId, _ticketId, msg.sender, _to);
    }

    /// @notice Cancels an event
    /// @param _eventId The ID of the event
    function cancelEvent(uint256 _eventId) external onlyOwner {
        require(events[_eventId].exists, "Event does not exist");
        require(!events[_eventId].canceled, "Event already canceled");

        events[_eventId].canceled = true;
        emit EventCanceled(_eventId);
    }

    /// @notice Refunds a ticket for a canceled event
    /// @param _eventId The ID of the event
    /// @param _ticketId The ID of the ticket
    function refundTicket(
        uint256 _eventId,
        uint256 _ticketId
    ) external whenNotPaused nonReentrant {
        require(events[_eventId].exists, "Event does not exist");
        require(events[_eventId].canceled, "Event is not canceled");
        require(
            ticketOwners[_eventId][_ticketId] == msg.sender,
            "Not ticket owner"
        );

        ticketOwners[_eventId][_ticketId] = address(0);
        for (uint256 i = 0; i < userTickets[_eventId][msg.sender].length; i++) {
            if (userTickets[_eventId][msg.sender][i] == _ticketId) {
                userTickets[_eventId][msg.sender][i] = userTickets[_eventId][
                    msg.sender
                ][userTickets[_eventId][msg.sender].length - 1];
                userTickets[_eventId][msg.sender].pop();
                break;
            }
        }

        payable(msg.sender).transfer(events[_eventId].ticketPrice);
        emit RefundIssued(
            _eventId,
            _ticketId,
            msg.sender,
            events[_eventId].ticketPrice
        );
    }

    /// @notice Verifies ticket ownership
    /// @param _eventId The ID of the event
    /// @param _ticketId The ID of the ticket
    /// @param _owner The address to verify
    /// @return bool Whether the address owns the ticket
    function verifyTicket(
        uint256 _eventId,
        uint256 _ticketId,
        address _owner
    ) external view returns (bool) {
        return ticketOwners[_eventId][_ticketId] == _owner;
    }

    /// @notice Withdraws contract balance to owner
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner).transfer(balance);
        emit FundsWithdrawn(owner, balance);
    }

    /// @notice Pauses the contract
    function pause() external onlyOwner {
        paused = true;
    }

    /// @notice Unpauses the contract
    function unpause() external onlyOwner {
        paused = false;
    }

    /// @notice Transfers ownership to a new address
    /// @param _newOwner The new owner's address
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid address");
        owner = _newOwner;
    }

    /// @notice Removes a canceled event to free storage
    /// @param _eventId The ID of the event
    function removeEvent(uint256 _eventId) external onlyOwner {
        require(events[_eventId].exists, "Event does not exist");
        require(events[_eventId].canceled, "Event not canceled");
        delete events[_eventId];
    }
}
