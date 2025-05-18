// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EventTicketing {
    address public owner;
    uint256 public eventCount;
    bool public paused;
    bool private locked;

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
    mapping(uint256 => mapping(uint256 => bool)) public ticketUsed;
    mapping(uint256 => mapping(address => uint256[])) public userTickets;

    event EventCreated(
        uint256 eventId,
        string name,
        uint256 date,
        uint256 ticketPrice,
        uint256 totalSupply
    );
    event TicketPurchased(uint256 eventId, uint256 ticketId, address buyer);
    event TicketVerified(
        uint256 eventId,
        uint256 ticketId,
        address owner,
        bool isValid
    );
    event TicketTransferred(
        uint256 eventId,
        uint256 ticketId,
        address from,
        address to
    );
    event EventCanceled(uint256 eventId);
    event TicketRefunded(uint256 eventId, uint256 ticketId, address owner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    constructor() {
        owner = msg.sender;
        eventCount = 0;
        paused = false;
    }

    function pause() external onlyOwner {
        paused = true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }

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
        require(_date > block.timestamp, "Event date must be in the future");
        require(_totalSupply > 0, "Supply must be greater than 0");

        eventCount++;
        events[eventCount] = Event({
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

        emit EventCreated(eventCount, _name, _date, _ticketPrice, _totalSupply);
    }

    function purchaseTicket(
        uint256 _eventId
    ) external payable whenNotPaused nonReentrant {
        require(msg.sender != address(0), "Invalid buyer address");
        Event storage evt = events[_eventId];
        require(evt.exists, "Event does not exist");
        require(!evt.canceled, "Event is canceled");
        require(evt.ticketsSold < evt.totalSupply, "No tickets available");
        require(msg.value >= evt.ticketPrice, "Insufficient payment");

        evt.ticketsSold++;
        uint256 ticketId = evt.ticketsSold;
        ticketOwners[_eventId][ticketId] = msg.sender;
        userTickets[_eventId][msg.sender].push(ticketId);

        if (msg.value > evt.ticketPrice) {
            (bool success, ) = payable(msg.sender).call{
                value: msg.value - evt.ticketPrice
            }("");
            require(success, "Refund failed");
        }

        emit TicketPurchased(_eventId, ticketId, msg.sender);
    }

    function purchaseTickets(
        uint256 _eventId,
        uint256 _quantity
    ) external payable whenNotPaused nonReentrant {
        require(msg.sender != address(0), "Invalid buyer address");
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

        for (uint256 i = 0; i < _quantity; i++) {
            evt.ticketsSold++;
            uint256 ticketId = evt.ticketsSold;
            ticketOwners[_eventId][ticketId] = msg.sender;
            userTickets[_eventId][msg.sender].push(ticketId);
            emit TicketPurchased(_eventId, ticketId, msg.sender);
        }

        if (msg.value > evt.ticketPrice * _quantity) {
            (bool success, ) = payable(msg.sender).call{
                value: msg.value - evt.ticketPrice * _quantity
            }("");
            require(success, "Refund failed");
        }
    }

    function verifyTicket(
        uint256 _eventId,
        address _attendee,
        uint256 _ticketId
    ) external returns (bool) {
        require(events[_eventId].exists, "Event does not exist");
        require(!events[_eventId].canceled, "Event is canceled");
        require(!ticketUsed[_eventId][_ticketId], "Ticket already used");
        bool isValid = ticketOwners[_eventId][_ticketId] == _attendee;
        if (isValid) {
            ticketUsed[_eventId][_ticketId] = true;
        }
        emit TicketVerified(_eventId, _ticketId, _attendee, isValid);
        return isValid;
    }

    function transferTicket(
        uint256 _eventId,
        uint256 _ticketId,
        address _to,
        uint256 _resalePrice
    ) external whenNotPaused {
        Event memory evt = events[_eventId];
        require(evt.exists, "Event does not exist");
        require(!evt.canceled, "Event is canceled");
        require(evt.transferable, "Tickets are non-transferable");
        require(
            ticketOwners[_eventId][_ticketId] == msg.sender,
            "Not ticket owner"
        );
        require(_resalePrice <= evt.resalePriceCap, "Resale price exceeds cap");
        require(_to != address(0), "Invalid recipient");
        require(!ticketUsed[_eventId][_ticketId], "Ticket already used");

        ticketOwners[_eventId][_ticketId] = _to;
        uint256[] storage senderTickets = userTickets[_eventId][msg.sender];
        for (uint256 i = 0; i < senderTickets.length; i++) {
            if (senderTickets[i] == _ticketId) {
                senderTickets[i] = senderTickets[senderTickets.length - 1];
                senderTickets.pop();
                break;
            }
        }
        userTickets[_eventId][_to].push(_ticketId);

        emit TicketTransferred(_eventId, _ticketId, msg.sender, _to);
    }

    function cancelEvent(uint256 _eventId) external onlyOwner {
        Event storage evt = events[_eventId];
        require(evt.exists, "Event does not exist");
        require(!evt.canceled, "Event already canceled");
        evt.canceled = true;
        emit EventCanceled(_eventId);
    }

    function refundTicket(
        uint256 _eventId,
        uint256 _ticketId
    ) external nonReentrant {
        Event memory evt = events[_eventId];
        require(evt.exists, "Event does not exist");
        require(evt.canceled, "Event not canceled");
        require(
            ticketOwners[_eventId][_ticketId] == msg.sender,
            "Not ticket owner"
        );
        require(!ticketUsed[_eventId][_ticketId], "Ticket already used");

        ticketOwners[_eventId][_ticketId] = address(0);
        uint256[] storage ownerTickets = userTickets[_eventId][msg.sender];
        for (uint256 i = 0; i < ownerTickets.length; i++) {
            if (ownerTickets[i] == _ticketId) {
                ownerTickets[i] = ownerTickets[ownerTickets.length - 1];
                ownerTickets.pop();
                break;
            }
        }

        (bool success, ) = payable(msg.sender).call{value: evt.ticketPrice}("");
        require(success, "Refund failed");

        emit TicketRefunded(_eventId, _ticketId, msg.sender);
    }

    function getEventDetails(
        uint256 _eventId
    )
        external
        view
        returns (
            string memory name,
            string memory description,
            string memory location,
            uint256 date,
            uint256 ticketPrice,
            uint256 totalSupply,
            uint256 ticketsSold,
            uint256 resalePriceCap,
            bool transferable,
            bool canceled
        )
    {
        Event memory evt = events[_eventId];
        require(evt.exists, "Event does not exist");
        return (
            evt.name,
            evt.description,
            evt.location,
            evt.date,
            evt.ticketPrice,
            evt.totalSupply,
            evt.ticketsSold,
            evt.resalePriceCap,
            evt.transferable,
            evt.canceled
        );
    }

    function getUserTickets(
        uint256 _eventId,
        address _user
    ) external view returns (uint256[] memory) {
        require(events[_eventId].exists, "Event does not exist");
        return userTickets[_eventId][_user];
    }

    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        (bool success, ) = payable(owner).call{value: balance}("");
        require(success, "Withdrawal failed");
    }
}
