import * as React from "react";
import { createRoot } from "react-dom/client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import FamHelpDesk from "./FamHelpDesk";
import UserAuthenticationProvider from "./provider/UserAuthenticationProvider";
import ApiProvider from "./provider/ApiProvider";
import MyFamiliesProvider from "./provider/MyFamiliesProvider";

// Global style reset
const style = document.createElement("style");
style.innerHTML = `
  html, body, #app {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }
`;
document.head.appendChild(style);

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      retry: 1,
    },
  },
});

createRoot(document.getElementById("app")).render(
  <QueryClientProvider client={queryClient}>
    <UserAuthenticationProvider>
      <ApiProvider>
        <MyFamiliesProvider>
          <FamHelpDesk />
        </MyFamiliesProvider>
      </ApiProvider>
    </UserAuthenticationProvider>
  </QueryClientProvider>,
);
