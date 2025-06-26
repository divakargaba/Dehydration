import { useEffect, useState } from "react";
import React from "react";
function Vitals() {
  const [hr, setHr] = useState("--");
  const [status, setStatus] = useState("Loading...");

  useEffect(() => {
    const fetchVitals = async () => {
      try {
        const res = await fetch("http://127.0.0.1:5000/hr");
        const data = await res.json();
        setHr(data.heart_rate);
        setStatus(data.status);
      } catch (err) {
        console.error("Failed to fetch vitals:", err);
        setStatus("Unavailable");
      }
    };

    fetchVitals();
    const interval = setInterval(fetchVitals, 4000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="text-xs mt-4 space-y-2 bg-white/60 dark:bg-black/20 p-3 rounded border dark:border-gray-700">
      <div><strong>Heart Rate:</strong> {hr} bpm</div>
      <div><strong>Status:</strong> {status}</div>
    </div>
  );
}

export default Vitals;
