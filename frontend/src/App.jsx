import React, { useEffect, useRef, useState } from "react";
import Sidebar from "./components/Sidebar";

function App() {
  const [chats, setChats] = useState({
    default: { name: "Default Chat", messages: [] },
  });
  const [currentChat, setCurrentChat] = useState("default");
  const [input, setInput] = useState("");
  const [isDark, setIsDark] = useState(false);
  const chatRef = useRef(null);

  const currentMessages = chats[currentChat]?.messages || [];

  const scrollToBottom = () => {
    chatRef.current?.scrollTo({ top: chatRef.current.scrollHeight, behavior: "smooth" });
  };

  const updateChatMessages = (updateFn) => {
    setChats((prevChats) => {
      const chat = prevChats[currentChat];
      const updatedMessages = updateFn(chat.messages);
      return {
        ...prevChats,
        [currentChat]: { ...chat, messages: updatedMessages },
      };
    });
  };

  const streamText = async (stream) => {
    const reader = stream.getReader();
    const decoder = new TextDecoder();
    let fullText = "";

    const pushChar = (char) => {
      fullText += char;
      updateChatMessages((msgs) => {
        const updated = [...msgs];
        updated[updated.length - 1] = { role: "assistant", content: fullText };
        return updated;
      });
      scrollToBottom();
    };

    while (true) {
      const { value, done } = await reader.read();
      if (done) break;

      const chunk = decoder.decode(value);
      for (const char of chunk) {
        await new Promise((resolve) => requestAnimationFrame(resolve)); // ~60fps
        pushChar(char);
      }
    }
  };

  const sendMessage = async (e) => {
    e.preventDefault();
    if (!input.trim()) return;

    const userMessage = { role: "user", content: input };
    updateChatMessages((msgs) => [...msgs, userMessage]);
    setInput("");

    updateChatMessages((msgs) => [...msgs, { role: "assistant", content: "" }]);

    const res = await fetch("http://127.0.0.1:5000/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message: input }),
    });

    if (!res.body) return;
    await streamText(res.body);
  };

  const toggleTheme = () => setIsDark(!isDark);

  const startNewChat = () => {
    const id = `chat-${Date.now()}`;
    setChats((prev) => ({
      ...prev,
      [id]: { name: "Untitled Chat", messages: [] },
    }));
    setCurrentChat(id);
  };

  const renameChat = (id, newName) => {
    setChats((prev) => ({
      ...prev,
      [id]: { ...prev[id], name: newName },
    }));
  };

  useEffect(() => {
    scrollToBottom();
  }, [currentMessages]);

  return (
    <div className={`flex h-screen ${isDark ? "bg-gray-900 text-white" : "bg-gray-50 text-gray-900"}`}>
      <Sidebar
        chats={chats}
        current={currentChat}
        setCurrent={setCurrentChat}
        startNewChat={startNewChat}
        isDark={isDark}
        toggleTheme={toggleTheme}
        renameChat={renameChat}
      />
      <div className="flex flex-col flex-1">
        <div className="text-2xl font-bold p-4 border-b flex justify-between items-center">
          <span>{chats[currentChat]?.name || "Hydration Assistant"}</span>
        </div>
        <div ref={chatRef} className="flex-1 overflow-y-auto p-4 space-y-4">
          {currentMessages.map((msg, idx) => (
            <div
              key={idx}
              className={`max-w-xl p-3 rounded-lg text-sm whitespace-pre-wrap shadow-md transition-all duration-200 ease-in-out ${
                msg.role === "user" ? "bg-blue-100 self-end ml-auto" : "bg-red-100 self-start"
              }`}
            >
              <strong className="block mb-1">{msg.role === "user" ? "You" : "Assistant"}:</strong>
              {msg.content}
            </div>
          ))}
        </div>
        <form onSubmit={sendMessage} className="flex gap-2 p-4 border-t">
          <input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            className="flex-1 border rounded p-2 focus:outline-none focus:ring-2 focus:ring-blue-400"
            placeholder="Type your message..."
          />
          <button className="bg-blue-500 text-white px-4 rounded hover:bg-blue-600">Send</button>
        </form>
      </div>
    </div>
  );
}

export default App;

