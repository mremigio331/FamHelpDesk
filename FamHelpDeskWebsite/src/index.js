import * as React from "react";
import { createRoot } from "react-dom/client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import FamHelpDesk from "./FamHelpDesk";
import UserAuthenticationProvider from "./provider/UserAuthenticationProvider";
import ApiProvider from "./provider/ApiProvider";
import MyFamiliesProvider from "./provider/MyFamiliesProvider";
import MobileDetectionProvider from "./provider/MobileDetectionProvider";

// Global style reset
const style = document.createElement("style");
style.innerHTML = `
  html, body, #app {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }
  
  /* Mobile font scaling */
  @media (max-width: 768px) {
    html {
      font-size: 14px;
    }
  }
  
  @media (max-width: 480px) {
    html {
      font-size: 12px;
    }
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
    <MobileDetectionProvider>
      <UserAuthenticationProvider>
        <ApiProvider>
          <MyFamiliesProvider>
            <FamHelpDesk />
          </MyFamiliesProvider>
        </ApiProvider>
      </UserAuthenticationProvider>
    </MobileDetectionProvider>
  </QueryClientProvider>,
);
