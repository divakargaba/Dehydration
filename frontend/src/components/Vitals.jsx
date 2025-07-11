import { useEffect, useState } from "react";
import React from "react";

function Vitals({ isDark = false }) {
  const [metrics, setMetrics] = useState({
    "Body Temp": "--",
    "Heart Rate": "--",
    "Steps": "--",
    "Active Energy": "--",
    "Water Intake": "--"
  });
  const [prediction, setPrediction] = useState("Loading...");
  const [status, setStatus] = useState("Loading...");
  const [lastUpdate, setLastUpdate] = useState("--");

  useEffect(() => {
    const updateVitals = async () => {
      try {
        // Fetch live metrics from backend
        const metricsRes = await fetch("http://127.0.0.1:5000/latest_metrics");
        const liveMetrics = await metricsRes.json();
        setMetrics(liveMetrics);

        // Fetch ANN prediction
        const predRes = await fetch("http://127.0.0.1:5000/predict_ann");
        const predData = await predRes.json();
        setPrediction(predData.prediction !== undefined ? predData.prediction : "N/A");
        setStatus(predData.status || "N/A");

        setLastUpdate(new Date().toLocaleTimeString());
      } catch (err) {
        console.error("Failed to update vitals:", err);
        setPrediction("Unavailable");
        setStatus("Unavailable");
      }
    };
    updateVitals();
    const interval = setInterval(updateVitals, 4000);
    return () => clearInterval(interval);
  }, []);

  const getStatusColor = (status) => {
    if (status?.toLowerCase().includes('hydrated')) return 'text-green-500';
    if (status?.toLowerCase().includes('dehydrated')) return 'text-red-500';
    if (status?.toLowerCase().includes('moderate')) return 'text-yellow-500';
    return 'text-gray-500';
  };

  const getMetricIcon = (metricName) => {
    const icons = {
      "Body Temp": "M12 9v3m0 0v3m0-3h3m-3 0H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z",
      "Heart Rate": "M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z",
      "Steps": "M13 7h8m0 0v8m0-8l-8 8-4-4-6 6",
      "Active Energy": "M13 10V3L4 14h7v7l9-11h-7z",
      "Water Intake": "M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.99l-.318.158a6 6 0 01-3.86.99l-.318-.158a6 6 0 00-3.86-.99l-2.387.477a2 2 0 00-1.022.547A2 2 0 004 17.5V19a2 2 0 002 2h12a2 2 0 002-2v-1.5a2 2 0 00-.572-1.072z"
    };
    return icons[metricName] || "M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z";
  };

  const getMetricColor = (metricName) => {
    const colors = {
      "Body Temp": "text-orange-500",
      "Heart Rate": "text-red-500",
      "Steps": "text-green-500",
      "Active Energy": "text-yellow-500",
      "Water Intake": "text-blue-500"
    };
    return colors[metricName] || "text-gray-500";
  };

  return (
    <div className={`space-y-4 ${isDark ? "text-white" : "text-gray-900"}`}>
      {/* Status Card */}
      <div className={`p-4 rounded-xl shadow-lg ${isDark ? "bg-gray-800 border border-gray-700" : "bg-white border border-gray-200"}`}>
        <div className="flex items-center justify-between mb-2">
          <h4 className="font-semibold">Hydration Status</h4>
          <div className={`w-2 h-2 rounded-full ${getStatusColor(status).replace('text-', 'bg-')}`}></div>
        </div>
        <div className={`text-lg font-bold ${getStatusColor(status)}`}>
          {status}
        </div>
        <div className={`text-sm ${isDark ? "text-gray-400" : "text-gray-600"}`}>
          Last updated: {lastUpdate}
        </div>
      </div>

      {/* Metrics Grid */}
      <div className="grid grid-cols-1 gap-3">
        {Object.entries(metrics).map(([key, value]) => (
          <div key={key} className={`p-3 rounded-lg shadow-md ${isDark ? "bg-gray-800 border border-gray-700" : "bg-white border border-gray-200"}`}>
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-3">
                <div className={`w-8 h-8 rounded-lg flex items-center justify-center ${isDark ? "bg-gray-700" : "bg-gray-100"}`}>
                  <svg className={`w-4 h-4 ${getMetricColor(key)}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d={getMetricIcon(key)} />
                  </svg>
                </div>
                <div>
                  <div className={`text-sm font-medium ${isDark ? "text-gray-300" : "text-gray-700"}`}>
                    {key}
                  </div>
                  <div className={`text-lg font-bold ${getMetricColor(key)}`}>
                    {value !== "--" ? (
                      <>
                        {value}
                        {key === "Body Temp" && "°C"}
                        {key === "Heart Rate" && " bpm"}
                        {key === "Steps" && ""}
                        {key === "Active Energy" && " kcal"}
                        {key === "Water Intake" && " L"}
                      </>
                    ) : (
                      "--"
                    )}
                  </div>
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* ANN Prediction */}
      <div className={`p-3 rounded-lg shadow-md ${isDark ? "bg-gray-800 border border-gray-700" : "bg-white border border-gray-200"}`}>
        <div className="flex items-center space-x-3">
          <div className={`w-8 h-8 rounded-lg flex items-center justify-center ${isDark ? "bg-gray-700" : "bg-gray-100"}`}>
            <svg className="w-4 h-4 text-purple-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
            </svg>
          </div>
          <div>
            <div className={`text-sm font-medium ${isDark ? "text-gray-300" : "text-gray-700"}`}>
              AI Prediction
            </div>
            <div className="text-lg font-bold text-purple-500">
              {prediction}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default Vitals;
