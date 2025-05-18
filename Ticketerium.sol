// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract Ticketerium is Ownable, Pausable {
    struct Event {
        string name;
        string description;
        string location;
        uint256 date;
        uint256 ticketPrice;
        uint256 totalSupply;
        uint256 ticketsSold;
        uint256 resalePriceCap;
        uint256 maxTicketsPerAddress;
        bool transferable;
        bool canceled;
        bool exists;
    }

    struct TradeRequest {
        address seller;
        address buyer;
        uint256 ticketId;
        uint256 price;
        uint256 buyerIncentive;
        uint256 sellerIncentive;
        uint256 requestTimestamp;
        uint256 paymentWindow;
        bool active;
        bool accepted;
    }

    mapping(uint256 => Event) public events;
    mapping(uint256 => mapping(uint256 => address)) public ticketOwners;
    mapping(uint256 => mapping(uint256 => bool)) public ticketRefunded;
    mapping(uint256 => uint256) public eventFunds;
    mapping(address => mapping(uint256 => uint256[])) public userTickets;
    mapping(uint256 => mapping(uint256 => TradeRequest)) public tradeRequests;
    mapping(address => mapping(uint256 => uint256)) public trustViolations;

    uint256 public eventCounter;
    uint256 public platformIncentive = 0.001 ether;

    event EventCreated(uint256 indexed eventId, string name, uint256 date);
    event EventCanceled(uint256 indexed eventId);
    event TicketPurchased(
        uint256 indexed eventId,
        uint256 ticketId,
        address buyer
    );
    event RefundIssued(
        uint256 indexed eventId,
        uint256 ticketId,
        address to,
        uint256 amount
    );
    event FundsReleased(uint256 indexed eventId, address to, uint256 amount);
    event TradeRequested(
        uint256 indexed eventId,
        uint256 ticketId,
        address seller,
        address buyer,
        uint256 price,
        uint256 incentive
    );
    event TradeAccepted(
        uint256 indexed eventId,
        uint256 ticketId,
        address seller,
        address buyer,
        uint256 paymentWindow
    );
    event TradeCompleted(
        uint256 indexed eventId,
        uint256 ticketId,
        address seller,
        address buyer,
        uint256 price
    );
    event TradeRequestTimedOut(
        uint256 indexed eventId,
        uint256 ticketId,
        address seller,
        address buyer
    );
    event TradePaymentTimedOut(
        uint256 indexed eventId,
        uint256 ticketId,
        address seller,
        address buyer,
        uint256 incentiveToSeller
    );
    event TrustViolation(
        address indexed buyer,
        uint256 indexed eventId,
        uint256 violations
    );

    constructor() Ownable(msg.sender) {}

    function setPlatformIncentive(uint256 _incentive) external onlyOwner {
        require(_incentive > 0, "I1");
        platformIncentive = _incentive;
    }

    function createEvent(
        string memory _name,
        string memory _description,
        string memory _location,
        uint256 _date,
        uint256 _ticketPrice,
        uint256 _totalSupply,
        uint256 _resalePriceCap,
        uint256 _maxTicketsPerAddress,
        bool _transferable
    ) external onlyOwner whenNotPaused {
        require(bytes(_name).length > 0, "N1");
        require(_date > block.timestamp + 1 hours, "D1");
        require(_totalSupply > 0 && _totalSupply <= 10000, "S1");
        require(
            _maxTicketsPerAddress > 0 && _maxTicketsPerAddress <= _totalSupply,
            "M1"
        );
        require(_resalePriceCap >= _ticketPrice, "R1");

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
            maxTicketsPerAddress: _maxTicketsPerAddress,
            transferable: _transferable,
            canceled: false,
            exists: true
        });

        emit EventCreated(eventCounter, _name, _date);
    }

    function purchaseTickets(
        uint256 _eventId,
        uint256 _quantity
    ) external payable whenNotPaused {
        Event storage eventData = events[_eventId];
        require(eventData.exists, "E1");
        require(!eventData.canceled, "C1");
        require(block.timestamp < eventData.date, "T1");
        require(_quantity > 0, "Q1");
        require(
            eventData.ticketsSold + _quantity <= eventData.totalSupply,
            "A1"
        );
        require(msg.value == eventData.ticketPrice * _quantity, "P1");
        require(
            userTickets[msg.sender][_eventId].length + _quantity <=
                eventData.maxTicketsPerAddress,
            "M2"
        );
        require(trustViolations[msg.sender][_eventId] < 5, "V1");

        for (uint256 i = 0; i < _quantity; i++) {
            eventData.ticketsSold++;
            uint256 ticketId = eventData.ticketsSold;
            ticketOwners[_eventId][ticketId] = msg.sender;
            userTickets[msg.sender][_eventId].push(ticketId);
            emit TicketPurchased(_eventId, ticketId, msg.sender);
        }

        eventFunds[_eventId] += msg.value;
    }

    function cancelEvent(uint256 _eventId) external onlyOwner {
        Event storage eventData = events[_eventId];
        require(eventData.exists, "E1");
        require(!eventData.canceled, "C1");

        eventData.canceled = true;

        for (
            uint256 ticketId = 1;
            ticketId <= eventData.ticketsSold;
            ticketId++
        ) {
            if (!ticketRefunded[_eventId][ticketId]) {
                address ticketOwner = ticketOwners[_eventId][ticketId];
                if (ticketOwner != address(0)) {
                    ticketRefunded[_eventId][ticketId] = true;
                    ticketOwners[_eventId][ticketId] = address(0);
                    uint256 refundAmount = eventData.ticketPrice;
                    eventFunds[_eventId] -= refundAmount;
                    (bool success, ) = ticketOwner.call{value: refundAmount}(
                        ""
                    );
                    require(success, "R2");
                    emit RefundIssued(
                        _eventId,
                        ticketId,
                        ticketOwner,
                        refundAmount
                    );
                }
            }
        }

        emit EventCanceled(_eventId);
    }

    function refundTicket(
        uint256 _eventId,
        uint256 _ticketId
    ) external whenNotPaused {
        Event storage eventData = events[_eventId];
        require(eventData.exists, "E1");
        require(eventData.canceled, "C2");
        require(ticketOwners[_eventId][_ticketId] == msg.sender, "O1");
        require(!ticketRefunded[_eventId][_ticketId], "R3");

        ticketRefunded[_eventId][_ticketId] = true;
        ticketOwners[_eventId][_ticketId] = address(0);
        uint256 refundAmount = eventData.ticketPrice;
        eventFunds[_eventId] -= refundAmount;

        (bool success, ) = msg.sender.call{value: refundAmount}("");
        require(success, "R2");

        emit RefundIssued(_eventId, _ticketId, msg.sender, refundAmount);
    }

    function releaseFunds(uint256 _eventId) external onlyOwner {
        Event storage eventData = events[_eventId];
        require(eventData.exists, "E1");
        require(!eventData.canceled, "C1");
        require(block.timestamp >= eventData.date, "T2");
        require(eventFunds[_eventId] > 0, "F1");

        uint256 amount = eventFunds[_eventId];
        eventFunds[_eventId] = 0;

        (bool success, ) = owner().call{value: amount}("");
        require(success, "F2");

        emit FundsReleased(_eventId, owner(), amount);
    }

    function requestTicketTrade(
        uint256 _eventId,
        uint256 _ticketId,
        address _seller,
        uint256 _price
    ) external payable whenNotPaused {
        Event storage eventData = events[_eventId];
        require(eventData.exists, "E1");
        require(!eventData.canceled, "C1");
        require(eventData.transferable, "TR1");
        require(ticketOwners[_eventId][_ticketId] == _seller, "O2");
        require(_seller != msg.sender, "S1");
        require(_price <= eventData.resalePriceCap, "R1");
        require(msg.value == platformIncentive, "I2");
        require(!tradeRequests[_eventId][_ticketId].active, "TR2");

        tradeRequests[_eventId][_ticketId] = TradeRequest({
            seller: _seller,
            buyer: msg.sender,
            ticketId: _ticketId,
            price: _price,
            buyerIncentive: msg.value,
            sellerIncentive: 0,
            requestTimestamp: block.timestamp,
            paymentWindow: 0,
            active: true,
            accepted: false
        });

        emit TradeRequested(
            _eventId,
            _ticketId,
            _seller,
            msg.sender,
            _price,
            msg.value
        );
    }

    function acceptTicketTrade(
        uint256 _eventId,
        uint256 _ticketId,
        uint256 _paymentWindow
    ) external payable whenNotPaused {
        TradeRequest storage request = tradeRequests[_eventId][_ticketId];
        Event storage eventData = events[_eventId];
        require(eventData.exists, "E1");
        require(!eventData.canceled, "C1");
        require(request.active, "TR3");
        require(request.seller == msg.sender, "S2");
        require(block.timestamp <= request.requestTimestamp + 600, "T3");
        require(msg.value == platformIncentive, "I2");
        require(_paymentWindow >= 600 && _paymentWindow <= 1800, "W1");

        request.sellerIncentive = msg.value;
        request.paymentWindow = _paymentWindow;
        request.accepted = true;

        emit TradeAccepted(
            _eventId,
            _ticketId,
            msg.sender,
            request.buyer,
            _paymentWindow
        );
    }

    function completeTicketTrade(
        uint256 _eventId,
        uint256 _ticketId
    ) external payable whenNotPaused {
        TradeRequest storage request = tradeRequests[_eventId][_ticketId];
        Event storage eventData = events[_eventId];
        require(eventData.exists, "E1");
        require(!eventData.canceled, "C1");
        require(request.active, "TR3");
        require(request.accepted, "TR4");
        require(request.buyer == msg.sender, "B1");
        require(
            block.timestamp <=
                request.requestTimestamp + 600 + request.paymentWindow,
            "T4"
        );
        require(msg.value == request.price, "P1");

        address seller = request.seller;
        uint256 price = request.price;
        uint256 totalIncentive = request.buyerIncentive +
            request.sellerIncentive;

        request.active = false;

        ticketOwners[_eventId][_ticketId] = msg.sender;
        uint256[] storage sellerTickets = userTickets[seller][_eventId];
        for (uint256 i = 0; i < sellerTickets.length; i++) {
            if (sellerTickets[i] == _ticketId) {
                sellerTickets[i] = sellerTickets[sellerTickets.length - 1];
                sellerTickets.pop();
                break;
            }
        }
        userTickets[msg.sender][_eventId].push(_ticketId);

        (bool sellerSuccess, ) = seller.call{value: price}("");
        require(sellerSuccess, "P2");

        (bool platformSuccess, ) = owner().call{value: totalIncentive}("");
        require(platformSuccess, "I3");

        emit TradeCompleted(_eventId, _ticketId, seller, msg.sender, price);
    }

    function cancelTradeRequest(
        uint256 _eventId,
        uint256 _ticketId
    ) external whenNotPaused {
        TradeRequest storage request = tradeRequests[_eventId][_ticketId];
        require(request.active, "TR3");
        require(block.timestamp > request.requestTimestamp + 600, "T5");
        require(
            msg.sender == request.buyer || msg.sender == request.seller,
            "A2"
        );

        request.active = false;

        (bool success, ) = request.buyer.call{value: request.buyerIncentive}(
            ""
        );
        require(success, "I4");

        emit TradeRequestTimedOut(
            _eventId,
            _ticketId,
            request.seller,
            request.buyer
        );
    }

    function cancelTradePayment(
        uint256 _eventId,
        uint256 _ticketId
    ) external whenNotPaused {
        TradeRequest storage request = tradeRequests[_eventId][_ticketId];
        require(request.active, "TR3");
        require(request.accepted, "TR4");
        require(
            block.timestamp >
                request.requestTimestamp + 600 + request.paymentWindow,
            "T6"
        );
        require(msg.sender == request.seller, "S2");

        request.active = false;

        uint256 halfIncentive = request.buyerIncentive / 2;
        (bool sellerSuccess, ) = request.seller.call{value: halfIncentive}("");
        require(sellerSuccess, "I5");

        (bool platformSuccess, ) = owner().call{
            value: request.buyerIncentive -
                halfIncentive +
                request.sellerIncentive
        }("");
        require(platformSuccess, "I3");

        trustViolations[request.buyer][_eventId]++;
        emit TrustViolation(
            request.buyer,
            _eventId,
            trustViolations[request.buyer][_eventId]
        );

        emit TradePaymentTimedOut(
            _eventId,
            _ticketId,
            request.seller,
            request.buyer,
            halfIncentive
        );
    }

    function getUserTickets(
        address _user
    )
        external
        view
        returns (uint256[] memory eventIds, uint256[][] memory ticketIds)
    {
        uint256[] memory tempEventIds = new uint256[](eventCounter);
        uint256[][] memory tempTicketIds = new uint256[][](eventCounter);
        uint256 count = 0;

        for (uint256 i = 1; i <= eventCounter; i++) {
            if (events[i].exists) {
                uint256[] memory tickets = userTickets[_user][i];
                if (tickets.length > 0) {
                    tempEventIds[count] = i;
                    tempTicketIds[count] = tickets;
                    count++;
                }
            }
        }

        eventIds = new uint256[](count);
        ticketIds = new uint256[][](count);
        for (uint256 i = 0; i < count; i++) {
            eventIds[i] = tempEventIds[i];
            ticketIds[i] = tempTicketIds[i];
        }

        return (eventIds, ticketIds);
    }

    function verifyTicket(
        uint256 _eventId,
        uint256 _ticketId,
        address _owner
    ) external view returns (bool) {
        return
            ticketOwners[_eventId][_ticketId] == _owner &&
            !ticketRefunded[_eventId][_ticketId];
    }

    function removeEvent(uint256 _eventId) external onlyOwner {
        Event storage eventData = events[_eventId];
        require(eventData.exists, "E1");
        require(eventData.canceled, "C2");
        require(eventFunds[_eventId] == 0, "F3");

        delete events[_eventId];
        emit EventCanceled(_eventId);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
