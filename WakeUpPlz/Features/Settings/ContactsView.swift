import SwiftUI
import ContactsUI

struct ContactsView: View {
    @Environment(RoutineStore.self) private var store
    @State private var picker = false
    @State private var manual = false
    @State private var name = ""
    @State private var phone = ""
    var body: some View {
        List {
            Section {
                Button { picker = true } label: { Label("연락처에서 가져오기", systemImage: "person.crop.circle.badge.plus") }
                Button("직접 입력하기") { manual = true }.foregroundStyle(Theme.secondary)
            } footer: { Text("선택한 이름과 전화번호만 이 iPhone에 저장해요. 번호가 여러 개라면 문자를 받을 번호를 선택하세요.") }
            Section("알림 받을 사람") {
                if store.routine.recipients.isEmpty { Text("아직 등록된 연락처가 없어요.").foregroundStyle(Theme.secondary) }
                ForEach(store.routine.recipients) { recipient in
                    VStack(alignment: .leading, spacing: 6) { Text(recipient.name); Text(recipient.phone).font(.subheadline).foregroundStyle(Theme.secondary) }
                }.onDelete { offsets in store.update { $0.recipients.remove(atOffsets: offsets) } }
            }
        }.appForm().navigationTitle("알림 받을 사람").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $picker) { ContactPicker { name, phone in _ = store.addRecipient(name: name, phone: phone) } }
            .sheet(isPresented: $manual) {
                NavigationStack {
                    Form { TextField("이름", text: $name); TextField("전화번호", text: $phone).keyboardType(.phonePad) }.appForm().navigationTitle("직접 입력")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("취소") { manual = false } }
                            ToolbarItem(placement: .confirmationAction) { Button("추가") { if store.addRecipient(name: name, phone: phone) { manual = false; name = ""; phone = "" } }.disabled(phone.isEmpty) }
                        }
                }.presentationDetents([.medium, .large])
            }
    }
}
private struct ContactPicker: UIViewControllerRepresentable {
    var selected: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(selected: selected, close: { dismiss() }) }
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        picker.predicateForSelectionOfContact = NSPredicate(value: false)
        picker.predicateForSelectionOfProperty = NSPredicate(format: "key == %@", CNContactPhoneNumbersKey)
        return picker
    }
    func updateUIViewController(_ controller: CNContactPickerViewController, context: Context) {}
    final class Coordinator: NSObject, CNContactPickerDelegate {
        let selected: (String, String) -> Void
        let close: () -> Void
        init(selected: @escaping (String, String) -> Void, close: @escaping () -> Void) { self.selected = selected; self.close = close }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect property: CNContactProperty) {
            guard let phone = property.value as? CNPhoneNumber else { return }
            selected(CNContactFormatter.string(from: property.contact, style: .fullName) ?? "", phone.stringValue)
            close()
        }
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) { close() }
    }
}
