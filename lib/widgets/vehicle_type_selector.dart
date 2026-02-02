import 'package:flutter/material.dart';

class VehicleTypeSelector extends StatefulWidget {
  final String initialVehicleType;
  final ValueChanged<String> onVehicleTypeChanged;
  final bool isCompact;

  const VehicleTypeSelector({
    Key? key,
    this.initialVehicleType = 'tricycle',
    required this.onVehicleTypeChanged,
    this.isCompact = false,
  }) : super(key: key);

  @override
  _VehicleTypeSelectorState createState() => _VehicleTypeSelectorState();
}

class _VehicleTypeSelectorState extends State<VehicleTypeSelector> {
  late String _selectedType;

  final List<Map<String, dynamic>> _vehicleTypes = [
    {'id': 'tricycle', 'label': 'Tricycle', 'icon': Icons.moped, 'color': Color(0xFF00BCD4)},
    {'id': 'motorcycle', 'label': 'Motorcycle', 'icon': Icons.two_wheeler, 'color': Color(0xFF9C27B0)},
    {'id': 'car', 'label': 'Car', 'icon': Icons.directions_car, 'color': Color(0xFF4CAF50)},
    {'id': 'van', 'label': 'Van', 'icon': Icons.directions_bus, 'color': Color(0xFF2196F3)},
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialVehicleType;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return Container(
        height: 50,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _vehicleTypes.length,
          separatorBuilder: (context, index) => SizedBox(width: 8),
          itemBuilder: (context, index) {
            final type = _vehicleTypes[index];
            final isSelected = _selectedType == type['id'];
            return _buildCompactItem(type, isSelected);
          },
        ),
      );
    }

    return Column(
      children: _vehicleTypes.map((type) {
        final isSelected = _selectedType == type['id'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildFullItem(type, isSelected),
        );
      }).toList(),
    );
  }

  Widget _buildCompactItem(Map<String, dynamic> type, bool isSelected) {
    return GestureDetector(
      onTap: () => _handleTypeSelection(type['id']),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? type['color'] : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: Colors.grey[400]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              type['icon'],
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 20,
            ),
            if (isSelected) ...[
              SizedBox(width: 4),
              Text(
                type['label'],
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFullItem(Map<String, dynamic> type, bool isSelected) {
    return InkWell(
      onTap: () => _handleTypeSelection(type['id']),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? type['color'].withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? type['color'] : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: type['color'].withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(type['icon'], color: type['color']),
            ),
            SizedBox(width: 16),
            Text(
              type['label'],
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? type['color'] : Colors.black87,
              ),
            ),
            Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: type['color'])
            else
              Icon(Icons.radio_button_unchecked, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _handleTypeSelection(String typeId) {
    setState(() {
      _selectedType = typeId;
    });
    widget.onVehicleTypeChanged(typeId);
  }
}
