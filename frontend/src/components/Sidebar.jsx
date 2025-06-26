// frontend/src/components/Sidebar.jsx
import React, { useState } from "react";
import Vitals from "./Vitals";

function Sidebar({ chats, current, setCurrent, startNewChat, isDark, toggleTheme, renameChat }) {
  const [editing, setEditing] = useState(null);
  const [newName, setNewName] = useState("");

  return (
    <div className={`w-64 border-r p-4 flex flex-col ${isDark ? "bg-gray-800 text-white" : "bg-white text-black"}`}>
      <div className="flex justify-between items-center mb-4">
        <h2 className="text-lg font-semibold">Chats</h2>
        <button
          className="text-sm text-blue-500 hover:underline"
          onClick={toggleTheme}
        >
          {isDark ? "Light" : "Dark"}
        </button>
      </div>

      <div className="flex-1 overflow-y-auto space-y-2 mb-4">
        {Object.entries(chats).map(([id, chat]) => (
          <div
            key={id}
            className={`p-2 rounded cursor-pointer transition ${
              id === current
                ? isDark
                  ? "bg-gray-700"
                  : "bg-blue-100"
                : "hover:bg-gray-200 dark:hover:bg-gray-700"
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
                  className="w-full p-1 rounded text-sm text-black"
                  value={newName}
                  onChange={(e) => setNewName(e.target.value)}
                  autoFocus
                />
              </form>
            ) : (
              <div className="flex justify-between items-center">
                <span className="truncate">{chat.name || "New Chat"}</span>
                <button
                  className="text-xs text-gray-500 ml-2"
                  onClick={(e) => {
                    e.stopPropagation();
                    setNewName(chat.name || "");
                    setEditing(id);
                  }}
                >
                  ✎
                </button>
              </div>
            )}
          </div>
        ))}

        {/* Vitals Panel */}
        <Vitals />
      </div>

      <button
        onClick={startNewChat}
        className="bg-blue-500 text-white py-2 px-3 rounded hover:bg-blue-600"
      >
        + New Chat
      </button>
    </div>
  );
}

export default Sidebar;
