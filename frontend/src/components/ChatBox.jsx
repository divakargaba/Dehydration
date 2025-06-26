import React from "react";

import { useEffect, useRef, useState } from "react";

export default function ChatBox() {
  const [messages, setMessages] = useState([
    { role: "assistant", content: "Hello! I'm a hydration assistant. How can I help you today?" },
  ]);
  const [input, setInput] = useState("");
  const chatRef = useRef(null);

  const sendMessage = async (e) => {
    e.preventDefault();
    if (!input.trim()) return;

    const userMessage = { role: "user", content: input };
    setMessages((prev) => [...prev, userMessage]);
    setInput("");

    const res = await fetch("http://127.0.0.1:5000/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message: input }),
    });

    const data = res.body;
    if (!data) return;

    const reader = data.getReader();
    const decoder = new TextDecoder();
    let botText = "";
    const botMessage = { role: "assistant", content: "" };
    setMessages((prev) => [...prev, botMessage]);

    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      botText += decoder.decode(value);
      setMessages((prev) => {
        const updated = [...prev];
        updated[updated.length - 1] = { ...botMessage, content: botText };
        return updated;
      });
    }
  };

  useEffect(() => {
    chatRef.current?.scrollTo(0, chatRef.current.scrollHeight);
  }, [messages]);

  return (
    <div className="flex flex-col flex-1">
      <div className="text-2xl font-bold bg-gray-100 p-4 border-b">Hydration Assistant</div>
      <div ref={chatRef} className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.map((msg, idx) => (
          <div
            key={idx}
            className={`max-w-xl p-3 rounded-lg text-sm whitespace-pre-wrap ${
              msg.role === "user" ? "bg-blue-100 self-end ml-auto" : "bg-red-100 self-start"
            }`}
          >
            <strong className="block mb-1">{msg.role === "user" ? "User" : "Assistant"}:</strong>
            {msg.content}
          </div>
        ))}
      </div>
      <form onSubmit={sendMessage} className="flex gap-2 p-4 border-t">
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          className="flex-1 border rounded p-2"
          placeholder="Type your message..."
        />
        <button className="bg-blue-500 text-white px-4 rounded">Send</button>
      </form>
    </div>
  );
}
