export function Input({ name, placeholder, onChange, value }) {
  return (
    <input
      name={name}
      placeholder={placeholder}
      onChange={onChange}
      value={value}
      className="border px-3 py-2 rounded w-full"
    />
  );
}
