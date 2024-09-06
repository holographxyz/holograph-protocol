// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { Colors } from "./Colors.sol";

contract Logger is Colors {
    function logFrame(string memory content) public view {
        // Filtrer les séquences de couleurs ANSI
        string memory filteredContent = filterAnsiColors(content);

        // Calculer la longueur du contenu filtré
        uint256 contentLength = bytes(filteredContent).length;

        // Construire la première et dernière ligne du cadre
        string memory topBottomLine = buildLine("\u2550", contentLength + 4);
        string memory topLine = string(abi.encodePacked("\u2554", topBottomLine, "\u2557"));
        string memory bottomLine = string(abi.encodePacked("\u255A", topBottomLine, "\u255D"));

        // Construire la ligne vide à l'intérieur du cadre
        string memory emptyLine = string(abi.encodePacked("\u2551", buildLine(" ", contentLength + 4), "\u2551"));

        // Construire la ligne du contenu
        string memory contentLine = string(abi.encodePacked(green("\u2551  "), content, green("  \u2551")));

        // Logger le cadre
        console.log(green(topLine));
        console.log(green(emptyLine));
        console.log(contentLine);
        console.log(green(emptyLine));
        console.log(green(bottomLine));
    }

    function buildLine(string memory character, uint256 length) internal pure returns (string memory line) {
        bytes memory charBytes = bytes(character);

        for (uint256 i = 0; i < length; i++) {
            line = string(abi.encodePacked(line, charBytes));
        }
    }

    function filterAnsiColors(string memory content) internal pure returns (string memory) {
        bytes memory contentBytes = bytes(content);
        bytes memory result = new bytes(contentBytes.length);
        uint256 j = 0;

        for (uint256 i = 0; i < contentBytes.length; i++) {
            if (contentBytes[i] == "\x1b") {
                // Skip the ANSI escape sequence
                while (i < contentBytes.length && contentBytes[i] != "m") i++;
            } else {
                result[j++] = contentBytes[i];
            }
        }

        bytes memory trimmedResult = new bytes(j);
        for (uint256 i = 0; i < j; i++) {
            trimmedResult[i] = result[i];
        }

        return string(trimmedResult);
    }
}
