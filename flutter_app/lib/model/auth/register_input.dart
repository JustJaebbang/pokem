enum RegisterField {
  id,
  nickname,
  name,
  password,
  confirmation,
  address,
  phone,
  email,
}

class RegisterInput {
  const RegisterInput({
    required this.id,
    required this.nickname,
    required this.name,
    required this.password,
    required this.confirmation,
    required this.address,
    required this.phone,
    required this.email,
  });
  final String id,
      nickname,
      name,
      password,
      confirmation,
      address,
      phone,
      email;
  Map<RegisterField, String> get fields => {
    RegisterField.id: id,
    RegisterField.nickname: nickname,
    RegisterField.name: name,
    RegisterField.password: password,
    RegisterField.confirmation: confirmation,
    RegisterField.address: address,
    RegisterField.phone: phone,
    RegisterField.email: email,
  };
}
