import * as React from "react";
import { createRoot } from "react-dom/client";
import FamHelpDesk from "./FamHelpDesk";
import UserAuthenticationProvider from "./provider/UserAuthenticationProvider";

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

createRoot(document.getElementById("app")).render(
  <UserAuthenticationProvider>
    <FamHelpDesk />
  </UserAuthenticationProvider>,
);
