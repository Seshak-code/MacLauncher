import Foundation

final class InputRouter {
    private weak var viewModel: LauncherViewModel?

    init(viewModel: LauncherViewModel) {
        self.viewModel = viewModel
    }

    func handleDirection(_ direction: MoveDirection) {
        viewModel?.moveFocus(direction)
    }

    func handleSelect() {
        viewModel?.activateFocused()
    }

    func handleCancel() {
        viewModel?.cancelOrBack()
    }

    func handleHomeButton() {
        viewModel?.returnToLauncher()
    }
    
    func handleAppSwitcher() {
        viewModel?.toggleAppSwitcher()
    }
    
    func handleKeyboardToggle() {
        viewModel?.toggleVirtualKeyboard()
    }
}
