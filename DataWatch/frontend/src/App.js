import React, { useEffect, useState } from 'react';

function App() {
  const [entries, setEntries] = useState([]);

  useEffect(() => {
    const interval = setInterval(() => {
      fetch('http://192.168.1.75:5050/latest')
        .then(res => {
          if (!res.ok) throw new Error("Network response was not ok");
          return res.json();
        })
        .then(data => {
          console.log("Fetched data:", data);
          setEntries(data);
        })
        .catch(err => console.error('Fetch failed:', err));
    }, 2000);

    return () => clearInterval(interval);
  }, []);

  return (
    <div style={{ padding: '2rem', fontFamily: 'sans-serif', background: '#f9f9f9', minHeight: '100vh' }}>
      <h1>Health Data History</h1>
      <button
        onClick={() => setEntries([])}
        style={{
          backgroundColor: '#dc3545',
          color: '#fff',
          border: 'none',
          padding: '0.5rem 1rem',
          borderRadius: '5px',
          marginBottom: '1rem'
        }}
      >
        Clear
      </button>

      {!entries || entries.length === 0 ? (
        <p>No data yet.</p>
      ) : (
        entries.map((entry, index) => (
          <div
            key={index}
            style={{
              backgroundColor: '#fff',
              borderRadius: '8px',
              padding: '1rem',
              marginBottom: '1rem',
              boxShadow: '0 1px 3px rgba(0,0,0,0.1)'
            }}
          >
            <strong>Entry {entries.length - index}</strong>
            <table style={{ width: '100%', marginTop: '0.5rem', borderCollapse: 'collapse' }}>
              <tbody>
                {Object.entries(entry).map(([key, value]) => (
                  <tr key={key}>
                    <td style={{ fontWeight: 'bold', padding: '4px 8px' }}>{key}</td>
                    <td style={{ padding: '4px 8px' }}>{value}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ))
      )}
    </div>
  );
}

export default App;