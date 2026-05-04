```typescript
interface User {
  id: string;
  name: string;
  email?: string;
}

const greet = (user: User): string => {
  return `Hello, ${user.name}`;
};
```
