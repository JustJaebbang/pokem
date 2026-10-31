import 'package:pokem_app/model/profile/user_profile.dart';
import 'package:pokem_app/model/products/product_photo.dart';

class ProfileState {
  const ProfileState({
    this.profile,
    this.loading = true,
    this.saving = false,
    this.error,
    this.photo,
    this.uploadedUrl,
    this.picking = false,
    this.removeImage = false,
  });
  final UserProfile? profile;
  final bool loading, saving, picking, removeImage;
  final String? error, uploadedUrl;
  final ProductPhoto? photo;
  ProfileState copyWith({
    UserProfile? profile,
    bool? loading,
    bool? saving,
    bool? picking,
    bool? removeImage,
    String? error,
    bool clearError = false,
    ProductPhoto? photo,
    String? uploadedUrl,
    bool clearPhoto = false,
    bool clearUploaded = false,
  }) => ProfileState(
    profile: profile ?? this.profile,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    picking: picking ?? this.picking,
    removeImage: removeImage ?? this.removeImage,
    error: clearError ? null : error ?? this.error,
    photo: clearPhoto ? null : photo ?? this.photo,
    uploadedUrl: clearUploaded ? null : uploadedUrl ?? this.uploadedUrl,
  );
}
