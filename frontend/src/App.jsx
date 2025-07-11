import React, { useEffect, useRef, useState } from "react";
import Sidebar from "./components/Sidebar";

function App() {
  const [chats, setChats] = useState({
    default: { name: "Hydration Assistant", messages: [] },
  });
  const [currentChat, setCurrentChat] = useState("default");
  const [input, setInput] = useState("");
  const [isDark, setIsDark] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
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
        await new Promise((resolve) => requestAnimationFrame(resolve));
        pushChar(char);
      }
    }
  };

  const sendMessage = async (e) => {
    e.preventDefault();
    if (!input.trim() || isLoading) return;

    setIsLoading(true);
    const userMessage = { role: "user", content: input };
    updateChatMessages((msgs) => [...msgs, userMessage]);
    setInput("");

    updateChatMessages((msgs) => [...msgs, { role: "assistant", content: "" }]);

    try {
      const res = await fetch("http://127.0.0.1:5000/api/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: input }),
      });

      if (!res.body) return;
      await streamText(res.body);
    } catch (error) {
      console.error("Failed to send message:", error);
      updateChatMessages((msgs) => {
        const updated = [...msgs];
        updated[updated.length - 1] = {
          role: "assistant",
          content: "Sorry, I'm having trouble connecting to the server. Please try again."
        };
        return updated;
      });
    } finally {
      setIsLoading(false);
    }
  };

  const toggleTheme = () => setIsDark(!isDark);

  const startNewChat = () => {
    const id = `chat-${Date.now()}`;
    setChats((prev) => ({
      ...prev,
      [id]: { name: "New Chat", messages: [] },
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
    <div className={`flex h-screen ${isDark ? "bg-gray-900 text-white" : "bg-gradient-to-br from-blue-50 to-indigo-100 text-gray-900"}`}>
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
        {/* Header */}
        <div className={`p-6 border-b ${isDark ? "bg-gray-800 border-gray-700" : "bg-white/80 backdrop-blur-sm border-gray-200"}`}>
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <div className={`w-3 h-3 rounded-full ${isDark ? "bg-green-400" : "bg-green-500"}`}></div>
              <h1 className="text-2xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
                {chats[currentChat]?.name || "Hydration Assistant"}
              </h1>
            </div>
            <div className="flex items-center space-x-2">
              <span className={`text-sm ${isDark ? "text-gray-400" : "text-gray-600"}`}>
                AI-Powered Hydration Monitoring
              </span>
            </div>
          </div>
        </div>

        {/* Chat Messages */}
        <div ref={chatRef} className="flex-1 overflow-y-auto p-6 space-y-6">
          {currentMessages.length === 0 && (
            <div className="flex flex-col items-center justify-center h-full space-y-4">
              <div className={`w-16 h-16 rounded-full flex items-center justify-center ${isDark ? "bg-gray-800" : "bg-white"} shadow-lg`}>
                <svg className="w-8 h-8 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                </svg>
              </div>
              <div className="text-center">
                <h3 className={`text-lg font-semibold ${isDark ? "text-white" : "text-gray-900"}`}>
                  Welcome to Hydration Assistant
                </h3>
                <p className={`mt-2 ${isDark ? "text-gray-400" : "text-gray-600"}`}>
                  Ask me about your hydration status, get personalized advice, or check your health metrics.
                </p>
              </div>
            </div>
          )}

          {currentMessages.map((msg, idx) => (
            <div
              key={idx}
              className={`flex ${msg.role === "user" ? "justify-end" : "justify-start"}`}
            >
              <div
                className={`max-w-2xl p-4 rounded-2xl shadow-lg transition-all duration-200 ease-in-out ${msg.role === "user"
                  ? `${isDark ? "bg-blue-600 text-white" : "bg-blue-500 text-white"} ml-12`
                  : `${isDark ? "bg-gray-800 border border-gray-700" : "bg-white border border-gray-200"} mr-12`
                  }`}
              >
                <div className="flex items-start space-x-3">
                  {msg.role === "assistant" && (
                    <div className={`w-8 h-8 rounded-full flex items-center justify-center ${isDark ? "bg-gray-700" : "bg-gray-100"} flex-shrink-0`}>
                      <svg className="w-4 h-4 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
                      </svg>
                    </div>
                  )}
                  <div className="flex-1">
                    <div className={`text-sm font-medium mb-1 ${msg.role === "user" ? "text-blue-100" : isDark ? "text-gray-300" : "text-gray-600"}`}>
                      {msg.role === "user" ? "You" : "Hydration Assistant"}
                    </div>
                    <div className={`whitespace-pre-wrap ${msg.role === "user" ? "text-white" : isDark ? "text-gray-200" : "text-gray-800"}`}>
                      {msg.content}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          ))}

          {isLoading && (
            <div className="flex justify-start">
              <div className={`max-w-2xl p-4 rounded-2xl shadow-lg ${isDark ? "bg-gray-800 border border-gray-700" : "bg-white border border-gray-200"} mr-12`}>
                <div className="flex items-center space-x-2">
                  <div className="flex space-x-1">
                    <div className="w-2 h-2 bg-blue-500 rounded-full animate-bounce"></div>
                    <div className="w-2 h-2 bg-blue-500 rounded-full animate-bounce" style={{ animationDelay: "0.1s" }}></div>
                    <div className="w-2 h-2 bg-blue-500 rounded-full animate-bounce" style={{ animationDelay: "0.2s" }}></div>
                  </div>
                  <span className={`text-sm ${isDark ? "text-gray-400" : "text-gray-600"}`}>Assistant is typing...</span>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Input Form */}
        <div className={`p-6 border-t ${isDark ? "bg-gray-800 border-gray-700" : "bg-white/80 backdrop-blur-sm border-gray-200"}`}>
          <form onSubmit={sendMessage} className="flex gap-3">
            <div className="flex-1 relative">
              <input
                value={input}
                onChange={(e) => setInput(e.target.value)}
                disabled={isLoading}
                className={`w-full px-4 py-3 rounded-xl border-2 focus:outline-none focus:ring-2 focus:ring-blue-500 transition-all duration-200 ${isDark
                  ? "bg-gray-700 border-gray-600 text-white placeholder-gray-400"
                  : "bg-white border-gray-300 text-gray-900 placeholder-gray-500"
                  }`}
                placeholder="Ask about your hydration status..."
              />
            </div>
            <button
              type="submit"
              disabled={isLoading || !input.trim()}
              className={`px-6 py-3 rounded-xl font-medium transition-all duration-200 flex items-center space-x-2 ${isLoading || !input.trim()
                ? `${isDark ? "bg-gray-600 text-gray-400" : "bg-gray-300 text-gray-500"} cursor-not-allowed`
                : "bg-blue-500 hover:bg-blue-600 text-white shadow-lg hover:shadow-xl transform hover:scale-105"
                }`}
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
              </svg>
              <span>Send</span>
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}

export default App;

