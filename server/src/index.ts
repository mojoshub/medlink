import express from 'express';
import http from 'http';
import { Server } from 'socket.io';
import cors from 'cors';

const app = express();
app.use(cors());
app.use(express.json());

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

const PORT = process.env.PORT || 3000;

interface Driver {
  id: string;
  name: string;
  phone: string;
  type: 'BLS' | 'ALS' | 'ICU';
  lat: number;
  lng: number;
  status: 'available' | 'assigned' | 'offline';
  socketId?: string;
}

interface Booking {
  id: string;
  patientName: string;
  patientPhone: string;
  patientLat: number;
  patientLng: number;
  destinationLat: number;
  destinationLng: number;
  status: 'requesting' | 'assigned' | 'enroute' | 'arrived' | 'inprogress' | 'completed';
  driverId?: string;
  ambulanceType: 'BLS' | 'ALS' | 'ICU';
}

const drivers = new Map<string, Driver>();
const bookings = new Map<string, Booking>();

// Prepopulate some mock drivers around Nairobi (-1.2858, 36.8200) for premium real-time visualization
const mockDrivers: Driver[] = [
  { id: 'driver_1', name: 'David Kiprop (BLS 01)', phone: '+254 712 345678', type: 'BLS', lat: -1.2820, lng: 36.8150, status: 'available' },
  { id: 'driver_2', name: 'Dr. Grace Kamau (ALS 02)', phone: '+254 722 987654', type: 'ALS', lat: -1.2900, lng: 36.8300, status: 'available' },
  { id: 'driver_3', name: 'ICU Critical Care (ICU 03)', phone: '+254 733 111222', type: 'ICU', lat: -1.2750, lng: 36.8210, status: 'available' },
];

mockDrivers.forEach(d => drivers.set(d.id, d));

// Simulate gentle driver movement to make the map feel alive
setInterval(() => {
  drivers.forEach((driver) => {
    if (driver.status === 'available') {
      // Drift slightly in Nairobi
      driver.lat += (Math.random() - 0.5) * 0.0006;
      driver.lng += (Math.random() - 0.5) * 0.0006;
    } else if (driver.status === 'assigned') {
      // Find active booking for driver and move closer to patient
      const activeBooking = Array.from(bookings.values()).find(
        b => b.driverId === driver.id && (b.status === 'assigned' || b.status === 'enroute' || b.status === 'arrived')
      );
      if (activeBooking) {
        let targetLat = activeBooking.patientLat;
        let targetLng = activeBooking.patientLng;

        if (activeBooking.status === 'inprogress') {
          targetLat = activeBooking.destinationLat;
          targetLng = activeBooking.destinationLng;
        }

        // Interpolate position closer to the target
        const speed = 0.0012; // speed factor
        const dLat = targetLat - driver.lat;
        const dLng = targetLng - driver.lng;
        const distance = Math.sqrt(dLat * dLat + dLng * dLng);

        if (distance > 0.0005) {
          driver.lat += (dLat / distance) * speed;
          driver.lng += (dLng / distance) * speed;
        } else {
          // Trigger arrived if very close to patient during pickup
          if (activeBooking.status === 'enroute') {
            activeBooking.status = 'arrived';
            io.to(`booking_${activeBooking.id}`).emit('booking:status_update', { status: 'arrived' });
            io.emit('bookings:update', Array.from(bookings.values()));
          }
        }

        io.to(`booking_${activeBooking.id}`).emit('booking:location_update', {
          lat: driver.lat,
          lng: driver.lng,
        });
      }
    }
    
    // Broadcast active drivers positions
    io.emit('drivers:update', Array.from(drivers.values()));
  });
}, 2000);

// REST API Endpoints
app.get('/api/drivers', (req, res) => {
  res.json(Array.from(drivers.values()));
});

app.get('/api/bookings', (req, res) => {
  res.json(Array.from(bookings.values()));
});

// Socket.IO
io.on('connection', (socket) => {
  console.log(`[Socket] Connected: ${socket.id}`);

  // Push immediate state
  socket.emit('drivers:update', Array.from(drivers.values()));
  socket.emit('bookings:update', Array.from(bookings.values()));

  // 1. Driver registration
  socket.on('driver:register', (data: { driverId: string }) => {
    const driver = drivers.get(data.driverId);
    if (driver) {
      driver.socketId = socket.id;
      driver.status = 'available';
      drivers.set(data.driverId, driver);
      console.log(`[Socket] Driver online: ${driver.name} (ID: ${data.driverId})`);
      io.emit('drivers:update', Array.from(drivers.values()));
    }
  });

  // 2. Manual/GPS Location Update
  socket.on('driver:location_update', (data: { driverId: string; lat: number; lng: number }) => {
    const driver = drivers.get(data.driverId);
    if (driver) {
      driver.lat = data.lat;
      driver.lng = data.lng;
      drivers.set(data.driverId, driver);
      
      // Update patient tracking room
      const activeBooking = Array.from(bookings.values()).find(
        b => b.driverId === data.driverId && b.status !== 'completed'
      );
      if (activeBooking) {
        io.to(`booking_${activeBooking.id}`).emit('booking:location_update', {
          lat: data.lat,
          lng: data.lng,
        });
      }
      
      io.emit('drivers:update', Array.from(drivers.values()));
    }
  });

  // 3. Request Booking
  socket.on('booking:request', (data: Omit<Booking, 'id' | 'status'>, callback) => {
    const bookingId = `booking_${Date.now()}`;
    const newBooking: Booking = {
      ...data,
      id: bookingId,
      status: 'requesting',
    };
    
    bookings.set(bookingId, newBooking);
    console.log(`[Socket] New Booking: ${bookingId} by ${data.patientName}`);
    
    socket.join(`booking_${bookingId}`);
    if (callback) callback({ status: 'success', bookingId });

    io.emit('bookings:update', Array.from(bookings.values()));
    matchmake(newBooking);
  });

  // 4. Accept Booking
  socket.on('booking:accept', (data: { bookingId: string; driverId: string }, callback) => {
    const booking = bookings.get(data.bookingId);
    const driver = drivers.get(data.driverId);
    
    if (booking && driver && booking.status === 'requesting') {
      booking.status = 'assigned';
      booking.driverId = data.driverId;
      bookings.set(data.bookingId, booking);

      driver.status = 'assigned';
      drivers.set(data.driverId, driver);

      socket.join(`booking_${booking.id}`);

      // Notify patient of driver match
      io.to(`booking_${booking.id}`).emit('booking:status_update', {
        status: 'assigned',
        driver: {
          name: driver.name,
          phone: driver.phone,
          type: driver.type,
          lat: driver.lat,
          lng: driver.lng,
        }
      });

      console.log(`[Socket] Ride accepted: ${booking.id} assigned to ${driver.name}`);
      io.emit('bookings:update', Array.from(bookings.values()));
      io.emit('drivers:update', Array.from(drivers.values()));

      if (callback) callback({ status: 'success' });
    } else {
      if (callback) callback({ status: 'error', message: 'Ride no longer available or driver not found' });
    }
  });

  // 5. Update booking status
  socket.on('booking:status_update', (data: { bookingId: string; status: Booking['status'] }, callback) => {
    const booking = bookings.get(data.bookingId);
    if (booking) {
      booking.status = data.status;
      bookings.set(data.bookingId, booking);

      io.to(`booking_${booking.id}`).emit('booking:status_update', {
        status: data.status,
      });

      console.log(`[Socket] Booking status: ${booking.id} is now ${data.status}`);

      if (data.status === 'completed' && booking.driverId) {
        const driver = drivers.get(booking.driverId);
        if (driver) {
          driver.status = 'available';
          drivers.set(booking.driverId, driver);
          io.emit('drivers:update', Array.from(drivers.values()));
        }
      }

      io.emit('bookings:update', Array.from(bookings.values()));
      if (callback) callback({ status: 'success' });
    } else {
      if (callback) callback({ status: 'error', message: 'Booking not found' });
    }
  });

  socket.on('disconnect', () => {
    console.log(`[Socket] Disconnected: ${socket.id}`);
  });
});

function getDistance(lat1: number, lon1: number, lat2: number, lon2: number) {
  const R = 6371; 
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c; 
}

function matchmake(booking: Booking) {
  let closestDriver: Driver | null = null;
  let minDistance = Infinity;

  // Search matching type first
  drivers.forEach((driver) => {
    if (driver.status === 'available' && driver.type === booking.ambulanceType) {
      const dist = getDistance(booking.patientLat, booking.patientLng, driver.lat, driver.lng);
      if (dist < minDistance) {
        minDistance = dist;
        closestDriver = driver;
      }
    }
  });

  // Fallback to any type if none of requested type is available
  if (!closestDriver) {
    drivers.forEach((driver) => {
      if (driver.status === 'available') {
        const dist = getDistance(booking.patientLat, booking.patientLng, driver.lat, driver.lng);
        if (dist < minDistance) {
          minDistance = dist;
          closestDriver = driver;
        }
      }
    });
  }

  if (closestDriver && (closestDriver as Driver).socketId) {
    console.log(`[Socket] Direct matching: Offer ${booking.id} to ${(closestDriver as Driver).name}`);
    io.to((closestDriver as Driver).socketId!).emit('booking:offer', {
      bookingId: booking.id,
      patientName: booking.patientName,
      patientPhone: booking.patientPhone,
      patientLat: booking.patientLat,
      patientLng: booking.patientLng,
      destinationLat: booking.destinationLat,
      destinationLng: booking.destinationLng,
      distance: minDistance,
    });
  } else {
    // If running in local demo mode without real active drivers sockets, automatically auto-assign after 3 seconds for testing ease
    console.log(`[Socket] No socket driver active. Auto-matching nearest in-memory driver for demo...`);
    
    // Choose nearest mock driver even if offline/no socket
    let nearestMock: Driver | null = null;
    let nearestDist = Infinity;
    drivers.forEach((driver) => {
      if (driver.status === 'available') {
        const dist = getDistance(booking.patientLat, booking.patientLng, driver.lat, driver.lng);
        if (dist < nearestDist) {
          nearestDist = dist;
          nearestMock = driver;
        }
      }
    });

    if (nearestMock) {
      const selected = nearestMock as Driver;
      setTimeout(() => {
        booking.status = 'assigned';
        booking.driverId = selected.id;
        bookings.set(booking.id, booking);

        selected.status = 'assigned';
        drivers.set(selected.id, selected);

        io.to(`booking_${booking.id}`).emit('booking:status_update', {
          status: 'assigned',
          driver: {
            name: selected.name,
            phone: selected.phone,
            type: selected.type,
            lat: selected.lat,
            lng: selected.lng,
          }
        });
        
        console.log(`[Demo Auto-Match] Auto-assigned ${booking.id} to nearest driver ${selected.name}`);
        io.emit('bookings:update', Array.from(bookings.values()));
        io.emit('drivers:update', Array.from(drivers.values()));

        // Start driving to patient
        setTimeout(() => {
          booking.status = 'enroute';
          io.to(`booking_${booking.id}`).emit('booking:status_update', { status: 'enroute' });
          io.emit('bookings:update', Array.from(bookings.values()));
        }, 3000);

      }, 3000);
    } else {
      io.to(`booking_${booking.id}`).emit('booking:no_drivers');
    }
  }
}

server.listen(PORT, () => {
  console.log(`[Server] Running on port ${PORT}`);
});
