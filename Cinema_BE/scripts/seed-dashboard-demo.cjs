// Local demo only. Uses the normal staff APIs; CASH records simulate counter sales, no bank/PayOS call.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

async function main() {
  const root = 'http://localhost:5000';
  assert.equal(new URL(root).hostname, 'localhost');
  const now = new Date();
  const local = new Date(now.getTime() + 7 * 3600000);
  const day = local.toISOString().slice(0, 10);
  const start = day + 'T00:00:00';
  const tomorrow = new Date(Date.parse(start + '+07:00') + 86400000).toISOString();
  const until = new Date(Date.parse(tomorrow) + 7 * 3600000).toISOString().slice(0, 19);
  const output = path.resolve(__dirname, '../../Cinema_Mobile/build', `dashboard-seed-${day}.json`);
  fs.mkdirSync(path.dirname(output), { recursive: true });
  const state = fs.existsSync(output) ? JSON.parse(fs.readFileSync(output, 'utf8')) : { day, purpose: 'Local dashboard demo', bookings: [] };
  const save = () => fs.writeFileSync(output, JSON.stringify(state, null, 2));
  const api = async (route, token, body) => {
    const response = await fetch(root + route, {
      method: body === undefined ? 'GET' : 'POST',
      headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    const text = await response.text();
    if (!response.ok) throw new Error(`${route}: HTTP ${response.status} ${text.slice(0, 400)}`);
    return text ? JSON.parse(text) : null;
  };
  const login = email => api('/api/v1/auth/login', null, { email, password: '123456' });
  const staff = await login('nhanvien1@cinema.com');
  const admin = await login('admin@cinema.com');
  const customer = await login('khachhang1@gmail.com');
  assert(staff.user.roles.includes('ROLE_STAFF'));
  assert(admin.user.roles.includes('ROLE_ADMIN'));
  assert(customer.user.roles.includes('ROLE_CUSTOMER'));
  const token = staff.accessToken;
  state.customerUserId = customer.user.userId;
  const allPages = async (route, pageKey = 'pageNumber') => {
    const result = [];
    for (let page = 1; ; page++) {
      const data = await api(route + (route.includes('?') ? '&' : '?') + `${pageKey}=${page}`, token);
      result.push(...data.items);
      if (page >= data.totalPages) return result;
    }
  };
  const shows = await allPages(`/api/showtimes/date-range?start=${day}T00:00:00&end=${until}&pageSize=50`);
  let demoShow;
  if (state.demoShowtimeId) demoShow = await api('/api/showtimes/' + state.demoShowtimeId, token);
  else {
    const previous = new Date(Date.parse(start + '+07:00') - 86400000 + 7 * 3600000).toISOString().slice(0, 10);
    const schedule = await allPages(`/api/showtimes/date-range?start=${previous}T00:00:00&end=${until}&pageSize=50`);
    const films = await allPages('/api/v1/movies/status/ACTIVE?size=50', 'page');
    films.sort((a, b) => a.durationMinutes - b.durationMinutes);
    const movie = films.find(m => m.durationMinutes > 0);
    assert(movie, 'No active movie available');
    const duration = movie.durationMinutes * 60000;
    const rooms = await allPages('/api/rooms?pageSize=50');
    let choice;
    for (const room of rooms) {
      const occupied = schedule.filter(s => s.roomId === room.id && s.status !== 'CANCELLED')
        .sort((a, b) => Date.parse(a.startTime + '+07:00') - Date.parse(b.startTime + '+07:00'));
      let candidate = Math.ceil((now.getTime() + 15 * 60000) / (5 * 60000)) * 5 * 60000;
      for (const s of occupied) {
        const begins = Date.parse(s.startTime + '+07:00'), ends = Date.parse(s.endTime + '+07:00');
        if (candidate >= ends + 15 * 60000) continue;
        if (candidate + duration + 15 * 60000 <= begins) break;
        candidate = Math.ceil((ends + 15 * 60000) / (5 * 60000)) * 5 * 60000;
      }
      if (candidate - now.getTime() <= 170 * 60000 && candidate + duration < Date.parse(until + '+07:00') &&
          (!choice || candidate < choice.at)) choice = { room, at: candidate };
    }
    assert(choice, 'No free room within the normal check-in window. Nothing was created.');
    const stamp = milliseconds => new Date(milliseconds + 7 * 3600000).toISOString().slice(0, 19);
    demoShow = await api('/api/showtimes', admin.accessToken, { movieId: movie.id, roomId: choice.room.id,
      startTime: stamp(choice.at), endTime: stamp(choice.at + duration), price: 80000, status: 'OPEN', format: '2D' });
    state.demoShowtimeId = demoShow.id;
    state.demoShowtime = { id: demoShow.id, movieTitle: movie.title, room: choice.room.name, startTime: demoShow.startTime, endTime: demoShow.endTime };
    save();
  }
  const future = shows.filter(s => s.status === 'OPEN' && Date.parse(s.startTime + '+07:00') > Date.now() + 20 * 60000 && s.id !== demoShow.id)
    .sort((a, b) => Date.parse(a.startTime + '+07:00') - Date.parse(b.startTime + '+07:00'));
  assert(future.length >= 3, 'Need three future showtimes today');
  const cases = [
    { name: 'checked-in', show: demoShow, seats: 2, paid: true, checkIn: true },
    { name: 'paid-four', show: future[0], seats: 4, paid: true },
    { name: 'paid-two', show: future[1], seats: 2, paid: true },
    { name: 'held-three', show: future[2], seats: 3, paid: false },
  ];
  for (const scenario of cases) {
    let entry = state.bookings.find(b => b.scenario === scenario.name);
    let booking = entry ? await api('/api/v1/bookings/' + entry.id, token) : null;
    if (booking?.status === 'EXPIRED' && !scenario.paid) booking = null;
    if (!booking) {
      const seats = await api('/api/seats/room/' + scenario.show.roomId, token);
      const occupied = await api(`/api/v1/bookings/showtime/${scenario.show.id}/occupied-seats`, token);
      const free = seats.filter(s => s.seatType === 'NORMAL' && !occupied.includes(s.id)).slice(0, scenario.seats);
      assert.equal(free.length, scenario.seats, 'Not enough free NORMAL seats');
      // Assign the existing demo customer, but omit email so test fixtures do not send mail.
      booking = await api('/api/v1/bookings', token, { userId: customer.user.userId,
        showtimeId: scenario.show.id, customerEmail: null, seats: free.map(s => ({ seatId: s.id })) });
      entry = { scenario: scenario.name, id: booking.id, code: booking.bookingCode };
      state.bookings = state.bookings.filter(b => b.scenario !== scenario.name);
      state.bookings.push(entry);
      save();
    }
    assert.equal(booking.userId, customer.user.userId);
    assert.equal(booking.customerEmail, null, 'Demo email must remain absent');
    if (scenario.paid && booking.status === 'PENDING') {
      const payment = await api('/api/v1/payments/cash', token, { bookingId: booking.id, amountReceived: booking.totalAmount });
      entry.paymentId = payment.id;
      save();
      booking = await api('/api/v1/bookings/' + booking.id, token);
    }
    if (scenario.checkIn && !booking.checkedInAt) booking = await api(`/api/v1/bookings/${booking.id}/check-in`, token, {});
    assert.equal(booking.status, scenario.paid ? 'CONFIRMED' : 'PENDING');
    if (scenario.checkIn) assert(booking.checkedInAt, 'Demo check-in was not recorded');
    Object.assign(entry, { status: booking.status, seats: booking.seats.map(s => s.seatLabel), showtimeId: booking.showtimeId,
      showTime: booking.showTime, amount: booking.totalAmount, checkedInAt: booking.checkedInAt, expiresAt: booking.expiresAt });
    save();
    console.log(JSON.stringify(entry));
  }
  const stats = await api(`/api/v1/bookings/showtimes/stats?start=${start}&end=${until}`, token);
  const sum = field => stats.reduce((total, row) => total + row[field], 0);
  state.expectedFixture = { sold: 8, held: 3, checkedIn: 2, withBookings: 4 };
  state.actualToday = { sold: sum('soldSeats'), held: sum('heldSeats'), checkedIn: sum('checkedInSeats'), withBookings: stats.length };
  for (const field of ['sold', 'held', 'checkedIn', 'withBookings']) assert(state.actualToday[field] >= state.expectedFixture[field]);
  const own = await api('/api/v1/bookings/assistant-summary', customer.accessToken);
  for (const created of state.bookings) {
    assert(own.bookings.some(b => b.id === created.id), `Customer cannot see demo order ${created.id}`);
  }
  state.createdAt = new Date().toISOString();
  save();
  console.log(JSON.stringify({ saved: output, demoShowtime: state.demoShowtime, actualToday: state.actualToday,
    cashSalesAreSimulated: true, payOsCalls: 0, customerEmails: 0 }));
}

main().catch(error => { console.error(error.message); process.exitCode = 1; });
