import React, { useState } from 'react';

export default function BlueprintButton({ blueprintString, label = "Copy Blueprint String" }: { blueprintString: string; label: string }) {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(blueprintString);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000); // Reset label after 2 seconds
    } catch (err) {
      console.error('Failed to copy blueprint string: ', err);
    }
  };

  return (
    <button
      onClick={handleCopy}
      className={`button button--primary ${copied ? 'button--success' : ''}`}
      style={{ margin: '0.5rem 0' }}
    >
      {copied ? '✔️ Copied to Clipboard!' : label}
    </button>
  );
}
