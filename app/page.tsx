'use client';

import {useEffect, useMemo, useState} from 'react';
import {searchEmojis} from 'emoogle-emoji-search-engine';

const STORAGE_KEY = 'recently-used-emojis';

type RecentEmoji = {
  emoji: string;
  count: number;
};

function loadRecent(): RecentEmoji[] {
  if (typeof window === 'undefined') return [];
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed.filter(
      (item) =>
        item &&
        typeof item.emoji === 'string' &&
        typeof item.count === 'number'
    );
  } catch {
    return [];
  }
}

function saveRecent(items: RecentEmoji[]) {
  if (typeof window === 'undefined') return;
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(items));
}

export default function Home() {
  const [query, setQuery] = useState('');
  const [recentUsed, setRecentUsed] = useState<RecentEmoji[]>([]);
  const [showInfo, setShowInfo] = useState(false);
  
  useEffect(() => {
    setRecentUsed(loadRecent());
  }, []);
  
  const results = useMemo(() => {
    const q = query.trim();
    if (!q) return [];
    return searchEmojis(q, 400);
  }, [query]);
  
  const copyToClipboard = async (emoji: string) => {
    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(emoji);
      } else {
        const textArea = document.createElement('textarea');
        textArea.value = emoji;
        textArea.style.position = 'fixed';
        textArea.style.left = '-999999px';
        textArea.style.top = '-999999px';
        document.body.appendChild(textArea);
        textArea.focus();
        textArea.select();
        document.execCommand('copy');
        textArea.remove();
      }
    } catch (err) {
      console.error('Copy failed:', err);
      navigator.clipboard?.writeText(emoji) || alert(`Copied: ${emoji}`);
    }
  };
  
  // ✅ Только обновляет счётчик
  const updateRecentUsed = (emoji: string) => {
    setRecentUsed((prev) => {
      const map = new Map<string, number>();
      for (const item of prev) map.set(item.emoji, item.count);
      map.set(emoji, (map.get(emoji) ?? 0) + 1);
      
      return Array.from(map.entries())
        .map(([emoji, count]) => ({ emoji, count }))
        .sort((a, b) => b.count - a.count || a.emoji.localeCompare(b.emoji))
        .slice(0, 50);
    });
  };

// ✅ Поиск: счётчик + копирование
  const handlePickEmoji = async (emoji: string) => {
    updateRecentUsed(emoji);
    await copyToClipboard(emoji);
  };

// ✅ Recent: только копирование
  const handleCopyEmoji = async (emoji: string) => {
    await copyToClipboard(emoji);
  };
  
  return (
    <main
      style={{
        maxWidth: 900,
        margin: '40px auto',
        padding: '0 16px',
        fontFamily: 'system-ui, sans-serif',
        position: 'relative'
      }}
    >
      <div style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        marginBottom: 12
      }}>
        <h1 style={{fontSize: 36, marginBottom: 12}}>Emoji Search</h1>
        <button
          onClick={() => setShowInfo(!showInfo)}
          style={{
            width: 40,
            height: 40,
            border: 'none',
            background: '#f0f0f0',
            borderRadius: '50%',
            cursor: 'pointer',
            color: '#666',
            fontSize: 18,
            fontWeight: 'bold',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            opacity: 0.8,
            transition: 'all 0.2s ease',
            boxShadow: '0 2px 8px rgba(0,0,0,0.15)',
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.background = '#e5e5e5';
            e.currentTarget.style.opacity = '1';
            e.currentTarget.style.transform = 'scale(1.05)';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.background = '#f0f0f0';
            e.currentTarget.style.opacity = '0.8';
            e.currentTarget.style.transform = '';
          }}
          title="About (⌘+?)"
        >
          ℹ
        </button>
      </div>
      
      
      <p style={{color: '#666', marginBottom: 24}}>
        Search emojis and keep track of your recently used ones.
      </p>
      
      <div style={{position: 'relative'}}>
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Try: amazing, happy, fire..."
          style={{
            width: '100%',
            padding: '14px 40px 14px 16px',
            fontSize: 18,
            border: '1px solid #ddd',
            borderRadius: 12,
            outline: 'none',
            boxSizing: 'border-box',
          }}
        />
        {query && (
          <button
            onClick={() => setQuery('')}
            style={{
              position: 'absolute',
              right: 12,
              top: '50%',
              transform: 'translateY(-50%)',
              width: 42,
              height: 42,
              border: 'none',
              background: 'none',
              cursor: 'pointer',
              color: '#666',
              fontSize: 28,
              lineHeight: 1,
              borderRadius: '50%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              opacity: 0.7,
              transition: 'all 0.2s',
              boxShadow: '0 1px 3px rgba(0,0,0,0.1)',
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = '#f0f0f0';
              e.currentTarget.style.opacity = '1';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'none';
              e.currentTarget.style.opacity = '0.7';
            }}
            title="Clear search"
          >
            ×
          </button>
        )}
      </div>
      
      <section style={{marginTop: 32}}>
        <h2 style={{fontSize: 20, marginBottom: 12}}>Results</h2>
        
        <div
          style={{
            height: 400,
            overflowY: 'auto',
            paddingRight: 6,
          }}
        >
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(4, minmax(0, 1fr))',
              gap: 12,
            }}
          >
            {results.length === 0 ? (
              <div style={{color: '#888', gridColumn: '1 / -1'}}>
                {query.trim() ? 'No results.' : 'Start typing to search.'}
              </div>
            ) : (
              results.map((emoji) => (
                <button
                  key={emoji}
                  onClick={() => handlePickEmoji(emoji)}
                  style={{
                    height: 72,
                    border: '1px solid #eee',
                    borderRadius: 14,
                    background: 'white',
                    cursor: 'pointer',
                    fontSize: 28,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    boxSizing: 'border-box',
                    transition: 'all 0.1s',
                  }}
                  onMouseDown={(e) => {
                    e.currentTarget.style.transform = 'scale(0.98)';
                    e.currentTarget.style.background = '#f0f0f0';
                  }}
                  onMouseUp={(e) => {
                    e.currentTarget.style.transform = '';
                    e.currentTarget.style.background = 'white';
                  }}
                  title="Click to use"
                >
                  {emoji}
                </button>
              ))
            )}
          </div>
        </div>
      </section>
      
      <section style={{marginTop: 32, borderTop: "1px solid black", paddingTop: "10px"}}>
        
        <div style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',  // ← Крестик справа
          marginBottom: 16
        }}>
          <h2 style={{
            fontSize: 20,
            margin: 0,
            fontWeight: 600
          }}>Recently used</h2>
          
          {recentUsed.length > 0 && (
            <button
              onClick={() => {
                setRecentUsed([]);
                saveRecent([]);
              }}
              style={{
                width: 28,
                height: 28,
                border: 'none',
                background: 'none',
                cursor: 'pointer',
                color: '#666',
                fontSize: 18,
                fontWeight: 'bold',
                borderRadius: '50%',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                opacity: 0.8,
                transition: 'all 0.2s ease',
                boxShadow: '0 1px 3px rgba(0,0,0,0.1)',
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.background = '#f5f5f5';
                e.currentTarget.style.opacity = '1';
                e.currentTarget.style.transform = 'scale(1.1)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.background = 'none';
                e.currentTarget.style.opacity = '0.8';
                e.currentTarget.style.transform = '';
              }}
              title="Clear recently used (⌘+Shift+R)"
            >
              ✕
            </button>
          )}
        
        </div>
        
        
        {recentUsed.length === 0 ? (
          <p style={{color: '#888'}}>No recently used emojis yet.</p>
        ) : (
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(4, minmax(0, 1fr))',
              gap: 12,
            }}
          >
            {recentUsed.map((item) => (
              <button
                key={item.emoji}
                onClick={() => handleCopyEmoji(item.emoji)}
                style={{
                  height: 72,
                  border: '1px solid #eee',
                  borderRadius: 14,
                  background: 'white',
                  cursor: 'pointer',
                  fontSize: 28,
                  position: 'relative',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  boxSizing: 'border-box',
                }}
                onMouseDown={(e) => e.currentTarget.style.transform = 'scale(0.98)'}
                onMouseUp={(e) => e.currentTarget.style.transform = ''}
                title={`Copy ${item}`}
              >
                <span>{item.emoji}</span>
                <span
                  style={{
                    position: 'absolute',
                    bottom: 6,
                    right: 8,
                    fontSize: 11,
                    color: '#666',
                  }}
                >
                  {item.count}
                </span>
              </button>
            ))}
          </div>
        )}
      </section>
      
      {showInfo && (
        <div
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'rgba(0,0,0,0.5)',
            zIndex: 1000,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            backdropFilter: 'blur(4px)',
          }}
          onClick={() => setShowInfo(false)}
        >
          <div
            style={{
              background: 'white',
              borderRadius: 16,
              padding: '32px 40px',
              maxWidth: 500,
              maxHeight: '80vh',
              overflowY: 'auto',
              boxShadow: '0 20px 60px rgba(0,0,0,0.3)',
              position: 'relative',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <button
              onClick={() => setShowInfo(false)}
              style={{
                position: 'absolute',
                top: 16,
                right: 16,
                width: 32,
                height: 32,
                border: 'none',
                background: 'none',
                fontSize: 20,
                color: '#999',
                cursor: 'pointer',
                borderRadius: '50%',
              }}
            >
              ✕
            </button>
            
            <h2 style={{fontSize: 24, marginBottom: 16, color: '#333'}}>
              Welcome to self-hosted EMoogle! 🚀
            </h2>
            
            <div style={{lineHeight: 1.6, color: '#555'}}>
              <p><strong>Fast emoji search</strong> powered by <a
                href="https://github.com/xitanggg/emoogle-emoji-search-engine" target="_blank"
                style={{color: '#0070f3'}}>emoogle-emoji-search-engine</a>.</p>
              <br/>
              <p><strong>Features:</strong></p>
              <ul style={{margin: '12px 0', paddingLeft: 24}}>
                <li>Instant search-as-you-type</li>
                <li>Recently used history (localStorage)</li>
                <li>Click to copy emoji</li>
                <li>Clear buttons for quick reset</li>
              </ul>
              <br/>
              <p style={{fontSize: 14, opacity: 0.8}}>
                Built with Next.js • Deployed on LXC • Made by KarelWintersky
              </p>
            </div>
          </div>
        </div>
      )}
    
    </main>
  );
}