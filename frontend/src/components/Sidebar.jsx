// frontend/src/components/Sidebar.jsx
import React, { useState } from "react";
import Vitals from "./Vitals";

function Sidebar({ chats, current, setCurrent, startNewChat, isDark, toggleTheme, renameChat }) {
  const [editing, setEditing] = useState(null);
  const [newName, setNewName] = useState("");

  return (
    <div className={`w-80 border-r ${isDark ? "bg-gray-800 border-gray-700 text-white" : "bg-white/90 backdrop-blur-sm border-gray-200 text-black"}`}>
      {/* Header */}
      <div className="p-6 border-b border-gray-200 dark:border-gray-700">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center space-x-3">
            <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${isDark ? "bg-blue-600" : "bg-gradient-to-r from-blue-500 to-purple-500"}`}>
              <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
              </svg>
            </div>
            <div>
              <h2 className="text-xl font-bold">Health Monitor</h2>
              <p className={`text-sm ${isDark ? "text-gray-400" : "text-gray-600"}`}>Real-time tracking</p>
            </div>
          </div>
          <button
            onClick={toggleTheme}
            className={`p-2 rounded-lg transition-all duration-200 ${isDark
              ? "hover:bg-gray-700 text-gray-300 hover:text-white"
              : "hover:bg-gray-100 text-gray-600 hover:text-gray-900"
              }`}
          >
            {isDark ? (
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" />
              </svg>
            ) : (
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" />
              </svg>
            )}
          </button>
        </div>

        <button
          onClick={startNewChat}
          className={`w-full py-3 px-4 rounded-xl font-medium transition-all duration-200 flex items-center justify-center space-x-2 ${isDark
            ? "bg-blue-600 hover:bg-blue-700 text-white shadow-lg"
            : "bg-gradient-to-r from-blue-500 to-purple-500 hover:from-blue-600 hover:to-purple-600 text-white shadow-lg"
            }`}
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
          </svg>
          <span>New Chat</span>
        </button>
      </div>

      {/* Vitals Panel */}
      <div className="p-6">
        <h3 className={`text-lg font-semibold mb-4 ${isDark ? "text-white" : "text-gray-900"}`}>
          Live Health Metrics
        </h3>
        <Vitals isDark={isDark} />
      </div>

      {/* Chat History */}
      <div className="flex-1 px-6">
        <h3 className={`text-lg font-semibold mb-4 ${isDark ? "text-white" : "text-gray-900"}`}>
          Chat History
        </h3>
        <div className="space-y-2">
          {Object.entries(chats).map(([id, chat]) => (
            <div
              key={id}
              className={`p-3 rounded-xl cursor-pointer transition-all duration-200 ${id === current
                ? isDark
                  ? "bg-blue-600 text-white shadow-lg"
                  : "bg-gradient-to-r from-blue-500 to-purple-500 text-white shadow-lg"
                : isDark
                  ? "hover:bg-gray-700 text-gray-300 hover:text-white"
                  : "hover:bg-gray-100 text-gray-700 hover:text-gray-900"
                }`}
              onClick={() => setCurrent(id)}
            >
              {editing === id ? (
                <form
                  onSubmit={(e) => {
                    e.preventDefault();
                    renameChat(id, newName);
                    setEditing(null);
                  }}
                >
                  <input
                    className={`w-full p-2 rounded-lg text-sm ${isDark
                      ? "bg-gray-700 border-gray-600 text-white"
                      : "bg-white border-gray-300 text-black"
                      } border focus:outline-none focus:ring-2 focus:ring-blue-500`}
                    value={newName}
                    onChange={(e) => setNewName(e.target.value)}
                    autoFocus
                  />
                </form>
              ) : (
                <div className="flex items-center justify-between">
                  <div className="flex items-center space-x-3">
                    <div className={`w-2 h-2 rounded-full ${id === current ? "bg-white" : isDark ? "bg-gray-500" : "bg-gray-400"}`}></div>
                    <span className="truncate font-medium">{chat.name || "New Chat"}</span>
                  </div>
                  <button
                    className={`p-1 rounded transition-colors ${id === current
                      ? "text-white hover:bg-white/20"
                      : isDark
                        ? "text-gray-400 hover:text-white hover:bg-gray-600"
                        : "text-gray-400 hover:text-gray-600 hover:bg-gray-200"
                      }`}
                    onClick={(e) => {
                      e.stopPropagation();
                      setNewName(chat.name || "");
                      setEditing(id);
                    }}
                  >
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                    </svg>
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

export default Sidebar;
